pragma solidity ^0.4.13;


import "./Owned.sol";
import "./FixedSupplyToken.sol";


contract Exchange is Owned {

    ///////////////////////
    // GENERAL STRUCTURE //
    ///////////////////////
    struct Offer {
        
        uint amount;
        address who;
    }

    struct OrderBook {
        
        uint higherPrice;
        uint lowerPrice;
        
        mapping (uint => Offer) offers;
        
        uint offersKey;
        uint offersLength;
    }

    struct Token {
        
        address tokenContract;

        string symbolName;
        
        
        mapping (uint => OrderBook) buyBook;
        
        uint curBuyPrice;
        uint lowestBuyPrice;
        uint amountBuyPrices;


        mapping (uint => OrderBook) sellBook;
        uint curSellPrice;
        uint highestSellPrice;
        uint amountSellPrices;

    }


    //we support a max of 255 tokens...
    mapping (uint8 => Token) tokens;
    uint8 symbolNameIndex;


    //////////////
    // BALANCES //
    //////////////
    mapping (address => mapping (uint8 => uint)) tokenBalanceForAddress;

    mapping (address => uint) balanceEthForAddress;




    ////////////
    // EVENTS //
    ////////////
     //EVENTS for Deposit/withdrawal
    event DepositForTokenReceived(address indexed _from, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event WithdrawalToken(address indexed _to, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event DepositForEthReceived(address indexed _from, uint _amount, uint _timestamp);
    event WithdrawalEth(address indexed _to, uint _amount, uint _timestamp);

    //events for orders
    event LimitSellOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event SellOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event SellOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);
    event LimitBuyOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event BuyOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event BuyOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);

    //events for management
    event TokenAddedToSystem(uint _symbolIndex, string _token, uint _timestamp);




    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL ETHER //
    //////////////////////////////////
    function depositEther() public payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;
        DepositForEthReceived(msg.sender,msg.value,now);
    }

    function withdrawEther(uint amountInWei) public {
        require(balanceEthForAddress[msg.sender] >= amountInWei);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
        WithdrawalEth(msg.sender,amountInWei,now);
    }

    function getEthBalanceInWei() public constant returns (uint) {
        return balanceEthForAddress[msg.sender];
    }


    //////////////////////
    // TOKEN MANAGEMENT //
    //////////////////////

    function addToken(string symbolName, address erc20TokenAddress) public onlyowner {
        require(!hasToken(symbolName));
        symbolNameIndex++;
        tokens[symbolNameIndex].tokenContract = erc20TokenAddress;
        tokens[symbolNameIndex].symbolName = symbolName;
        TokenAddedToSystem(symbolNameIndex,symbolName,now);
    }

    function hasToken(string symbolName) public constant returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }



     function getSymbolIndex(string symbolName) internal constant returns (uint8) {
        for (uint8 i = 1; i <= symbolNameIndex; i++) {
            if (stringsEqual(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }




    ////////////////////////////////
    // STRING COMPARISON FUNCTION //
    ////////////////////////////////
    function stringsEqual(string storage _a, string memory _b) internal constant returns (bool) {
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);
        if (a.length != b.length)
            return false;
        // @todo unroll this loop
        for (uint i = 0; i < a.length; i ++) {
            if (a[i] != b[i])
                return false;
        }
        return true;
    }


    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL TOKEN //
    //////////////////////////////////
    //MUST APPROVE IN ORDER TO DEPOSIT
    function depositToken(string symbolName, uint amount) public {
        require(hasToken(symbolName));
        uint8 index = getSymbolIndex(symbolName);
        require(tokens[index].tokenContract != address(0));
        ERC20Interface token = ERC20Interface(tokens[index].tokenContract);
        require(token.transferFrom(msg.sender,address(this),amount));
        require(tokenBalanceForAddress[msg.sender][index] + amount >= tokenBalanceForAddress[msg.sender][index]);
        tokenBalanceForAddress[msg.sender][index] += amount;
        DepositForTokenReceived(msg.sender,index,amount,now);
    }

    function withdrawToken(string symbolName, uint amount) public {
        require(hasToken(symbolName));
        uint8 index = getSymbolIndex(symbolName);
        require(tokens[index].tokenContract != address(0));
        ERC20Interface token = ERC20Interface(tokens[index].tokenContract);
        require(tokenBalanceForAddress[msg.sender][index] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][index] - amount <= tokenBalanceForAddress[msg.sender][index]);
        tokenBalanceForAddress[msg.sender][index] -= amount;
        require(token.transfer(msg.sender,amount));
        WithdrawalToken(msg.sender,index,amount,now);
    }

    function getBalance(string symbolName) public constant returns (uint) {
        require(hasToken(symbolName));
        uint8 index = getSymbolIndex(symbolName);
        return tokenBalanceForAddress[msg.sender][index];
    }





    /////////////////////////////
    // ORDER BOOK - BID ORDERS //
    /////////////////////////////
    function getBuyOrderBook(string symbolName) public constant returns (uint[], uint[]) {
        require(hasToken(symbolName));
        uint8 tokenIndex = getSymbolIndex(symbolName);
        uint[] memory pricesArray = new uint[](tokens[tokenIndex].amountBuyPrices);
        uint[] memory volumeArray = new uint[](tokens[tokenIndex].amountBuyPrices);
        uint currentPrice = tokens[tokenIndex].lowestBuyPrice;
        uint arraysIndex = 0;

        if (tokens[tokenIndex].curBuyPrice > 0) {
            uint volume = 0;
            uint offerKey = 0;
            while (currentPrice <= tokens[tokenIndex].curBuyPrice) {
                pricesArray[arraysIndex] = currentPrice;
                volume = 0;
                offerKey = tokens[tokenIndex].buyBook[currentPrice].offersKey;
                while (offerKey <= tokens[tokenIndex].buyBook[currentPrice].offersLength) {
                    volume += tokens[tokenIndex].buyBook[currentPrice].offers[offerKey].amount;
                    offerKey++;
                }
                volumeArray[arraysIndex] = volume;
                arraysIndex++;
                if (currentPrice == tokens[tokenIndex].buyBook[currentPrice].higherPrice) {
                    break;
                }else {
                    currentPrice = tokens[tokenIndex].buyBook[currentPrice].higherPrice;
                }
            }
        }
        return (pricesArray, volumeArray);

    }


    /////////////////////////////
    // ORDER BOOK - ASK ORDERS //
    /////////////////////////////
    function getSellOrderBook(string symbolName) public constant returns (uint[], uint[]) {
        require(hasToken(symbolName));
        uint8 tokenIndex = getSymbolIndex(symbolName);
        uint[] memory pricesArray = new uint[](tokens[tokenIndex].amountSellPrices);
        uint[] memory volumeArray = new uint[](tokens[tokenIndex].amountSellPrices);
        uint currentPrice = tokens[tokenIndex].highestSellPrice;
        uint arraysIndex = 0;

        if (tokens[tokenIndex].curSellPrice > 0) {
            uint volume = 0;
            uint offerKey = 0;
            while (currentPrice >= tokens[tokenIndex].curSellPrice) {
                pricesArray[arraysIndex] = currentPrice;
                volume = 0;
                offerKey = tokens[tokenIndex].sellBook[currentPrice].offersKey;
                while (offerKey <= tokens[tokenIndex].sellBook[currentPrice].offersLength) {
                    volume += tokens[tokenIndex].sellBook[currentPrice].offers[offerKey].amount;
                    offerKey++;
                }
                volumeArray[arraysIndex] = volume;
                arraysIndex++;
                if (0 == tokens[tokenIndex].sellBook[currentPrice].lowerPrice) {
                    break;
                }else {
                    currentPrice = tokens[tokenIndex].sellBook[currentPrice].lowerPrice;
                }
            }
        }
        return (pricesArray, volumeArray);
    }



    ////////////////////////////
    // NEW ORDER - BID ORDER //
    ///////////////////////////
    function buyToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenIndex = getSymbolIndex(symbolName);
        require(tokenIndex > 0);
        uint totalWeiNeeded = priceInWei*amount;
        require(totalWeiNeeded >= amount);
        require(totalWeiNeeded >= priceInWei);
        require(balanceEthForAddress[msg.sender] >= totalWeiNeeded);
        require(balanceEthForAddress[msg.sender] - totalWeiNeeded >= 0);
        balanceEthForAddress[msg.sender] -= totalWeiNeeded;
        if (tokens[tokenIndex].amountSellPrices == 0 || tokens[tokenIndex].curSellPrice > priceInWei) {
            addBuyOffer(tokenIndex,priceInWei,amount,msg.sender);
            uint orderKey = tokens[tokenIndex].buyBook[priceInWei].offersLength;
            LimitBuyOrderCreated(tokenIndex, msg.sender, amount, priceInWei, orderKey);
        }else {
            revert();//TODO
        }
    }
    function addBuyOffer(uint8 tokenIndex,uint priceInWei,uint amount,address buyer) internal {
        tokens[tokenIndex].buyBook[priceInWei].offersLength++;
        tokens[tokenIndex].buyBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offersLength] = Offer(amount,buyer);
        uint currentPrice = tokens[tokenIndex].curBuyPrice;
        uint lowestPrice = tokens[tokenIndex].lowestBuyPrice;
        if (tokens[tokenIndex].buyBook[priceInWei].offersLength == 1) {
            tokens[tokenIndex].buyBook[priceInWei].offersKey = 1;
            tokens[tokenIndex].amountBuyPrices++;
            if (lowestPrice == 0 || lowestPrice > priceInWei) {
                if (currentPrice == 0) {
                    tokens[tokenIndex].curBuyPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                }else {
                    tokens[tokenIndex].buyBook[lowestPrice].lowerPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = lowestPrice;
                }
                tokens[tokenIndex].lowestBuyPrice = priceInWei;
            }else if (priceInWei > currentPrice) {
                tokens[tokenIndex].buyBook[currentPrice].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].lowerPrice = currentPrice;
                tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[tokenIndex].curBuyPrice = priceInWei;
            }
        }else {
            bool found = false;
            uint prevPrice = 0;
            while (currentPrice > 0 && !found) {
                prevPrice = tokens[tokenIndex].buyBook[currentPrice].higherPrice;
                if (currentPrice < priceInWei && prevPrice > priceInWei ) {
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = prevPrice;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = currentPrice;
                    tokens[tokenIndex].buyBook[prevPrice].lowerPrice = priceInWei;
                    tokens[tokenIndex].buyBook[currentPrice].higherPrice = priceInWei;
                    found = true;
                }
                currentPrice = tokens[tokenIndex].buyBook[currentPrice].lowerPrice;
            }
        }
    }





    ////////////////////////////
    // NEW ORDER - ASK ORDER //
    ///////////////////////////
    function sellToken(string symbolName, uint priceInWei, uint amount) public {
        uint8 tokenIndex = getSymbolIndex(symbolName);
        require(tokenIndex > 0);
        uint totalWeiWanted = priceInWei*amount;
        require(totalWeiWanted >= amount);
        require(totalWeiWanted >= priceInWei);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] >= amount);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] - amount >= 0);
        require(balanceEthForAddress[msg.sender] + totalWeiWanted >= balanceEthForAddress[msg.sender]);
        tokenBalanceForAddress[msg.sender][tokenIndex] -= amount;
        if (tokens[tokenIndex].amountBuyPrices == 0 || tokens[tokenIndex].curBuyPrice < priceInWei) {
            addSellOffer(tokenIndex,priceInWei,amount,msg.sender);
            uint orderKey = tokens[tokenIndex].sellBook[priceInWei].offersLength;
            LimitSellOrderCreated(tokenIndex, msg.sender, amount, priceInWei, orderKey);
        }else {
            revert();//TODO
        }
    }
    function addSellOffer(uint8 tokenIndex,uint priceInWei,uint amount,address seller) internal {
        tokens[tokenIndex].sellBook[priceInWei].offersLength++;
        tokens[tokenIndex].sellBook[priceInWei].offers[tokens[tokenIndex].sellBook[priceInWei].offersLength] = Offer(amount,seller);
        uint currentPrice = tokens[tokenIndex].curSellPrice;
        uint highestPrice = tokens[tokenIndex].highestSellPrice;
        if (tokens[tokenIndex].sellBook[priceInWei].offersLength == 1) {
            tokens[tokenIndex].sellBook[priceInWei].offersKey = 1;
            tokens[tokenIndex].amountSellPrices++;
            if (highestPrice == 0 || highestPrice < priceInWei) {
                if (currentPrice == 0) {
                    tokens[tokenIndex].curSellPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = priceInWei;
                }else {
                    tokens[tokenIndex].sellBook[highestPrice].higherPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = highestPrice;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = priceInWei;
                }
                tokens[tokenIndex].highestSellPrice = priceInWei;
            }else if (priceInWei < currentPrice) {
                tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                tokens[tokenIndex].sellBook[priceInWei].higherPrice = currentPrice;
                tokens[tokenIndex].sellBook[currentPrice].lowerPrice = priceInWei;
                tokens[tokenIndex].curSellPrice = priceInWei;
            }
        }else {
            bool found = false;
            uint prevPrice = 0;
            while (currentPrice > 0 && !found) {
                prevPrice = tokens[tokenIndex].sellBook[currentPrice].lowerPrice;
                if (currentPrice > priceInWei && prevPrice < priceInWei ) {
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = prevPrice;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = currentPrice;
                    tokens[tokenIndex].sellBook[currentPrice].lowerPrice = priceInWei;
                    if (prevPrice > 0)
                        tokens[tokenIndex].sellBook[prevPrice].lowerPrice = priceInWei;
                    found = true;
                }
                currentPrice = tokens[tokenIndex].sellBook[currentPrice].higherPrice;
            }
        }
    }



    //////////////////////////////
    // CANCEL LIMIT ORDER LOGIC //
    //////////////////////////////
    function cancelOrder(string symbolName, bool isSellOrder, uint priceInWei, uint offerKey) public {
        uint8 tokenIndex = getSymbolIndex(symbolName);
        require(tokenIndex > 0);
        if (isSellOrder) {
            cancelSellOrder(tokenIndex,priceInWei,offerKey,msg.sender);
        }else {
            cancelBuyOrder(tokenIndex,priceInWei,offerKey,msg.sender);
        }
    }

    function cancelBuyOrder(uint8 tokenIndex, uint priceInWei, uint offerKey, address who) internal {
        require(offerKey <= tokens[tokenIndex].buyBook[priceInWei].offersKey);
        require(tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].who == who);
        uint amount = tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].amount;
        uint totalWeiToRefund = priceInWei*amount;
        require(totalWeiToRefund >= amount);
        require(totalWeiToRefund >= priceInWei);
        require(balanceEthForAddress[who] + totalWeiToRefund >= balanceEthForAddress[who]);
        balanceEthForAddress[who] += totalWeiToRefund;
        tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].amount = 0;
        BuyOrderCanceled(tokenIndex, priceInWei, offerKey);
    }
    function cancelSellOrder(uint8 tokenIndex, uint priceInWei, uint offerKey, address who) internal {
        require(offerKey <= tokens[tokenIndex].sellBook[priceInWei].offersKey);
        require(tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].who == who);
        uint amount = tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].amount;
        require(tokenBalanceForAddress[who][tokenIndex] + amount >= tokenBalanceForAddress[who][tokenIndex]);
        tokenBalanceForAddress[who][tokenIndex] += amount;
        tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].amount = 0;
        SellOrderCanceled(tokenIndex, priceInWei, offerKey);
    }



}