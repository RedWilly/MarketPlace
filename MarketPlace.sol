// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant1() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract NFTMarket is ReentrancyGuard {

    uint256 maxRoyaltyPercentage;
    uint256 ownerPercentage;
    address payable ownerFeesAccount;
    address owner;

    //Structs
    struct listingFixPrice {
        uint256 price;
        address seller;
    }

    struct royalty {
        address payable creator;
        uint256 percentageRoyalty;
    }

    struct listingAuction {
        uint256 startPrice;
        address seller;
        uint256 timeInSeconds;
        uint256 endTime;
    }

    struct bidding {
        address Highestbidder;
        uint256 currentPrice;
    }

    //Constructor
    constructor() {
        owner = msg.sender;
    }

    //Modifiers
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    //Events
    event tokenListedFixPrice(address indexed seller, uint256 indexed tokenId, uint256 indexed price);
    event tokenUnlistedFixPrice(address indexed seller, uint256 indexed tokenId);
    event tokenListedAuction(address seller, address token, uint256 tokenId, uint256 startPrice, uint256 endPrice);
    event tokenUnlistedAuction(address seller, address token, uint256 tokenId);
    event nftBoughtFixPrice(address indexed buyer, uint256 indexed tokenId, uint256 indexed price);
    event nftBiddedOnAuction(address buyer, address token, uint256 tokenId, uint256 biddingPrice);
    event nftWithdrawnAuction(address indexed buyer, address token, uint256 indexed tokenId, uint256 indexed price);

    //Mappings
    mapping(address => mapping(uint256 =>  listingFixPrice)) listingFixPrices;
    mapping(address => mapping(uint256 =>listingAuction)) listingAuctions;
    mapping(address => mapping(uint256 => royalty)) royalties;
    mapping(address => mapping(uint256 => bidding)) biddings;
    mapping(address => uint256) balanceOf;

    function setMaxRoyaltyPercentage(uint256 _maxRoyaltyPercentage) public onlyOwner {
        maxRoyaltyPercentage = _maxRoyaltyPercentage;
    }

    function setOwnerPercentage(uint256 _ownerPercentage) public onlyOwner {
        ownerPercentage = _ownerPercentage;
    }

    function setOwnerAccount(address payable _ownerFeesAccount) public onlyOwner {
        ownerFeesAccount = _ownerFeesAccount;
    }

    function listNftFixPrice (uint256 _price, address _token, uint256 _tokenId, address payable _creator, uint256 _royalty) public {
        require(_token != address(0), "Token address cannot be 0");
        require (IERC721(_token).ownerOf(_tokenId) == msg.sender, "You Dont Own the Given Token");
        require (_price > 0, "Price Must Be Greater Than 0");
        require (IERC721(_token).isApprovedForAll(msg.sender, address(this)), "This Contract is not Approved");
        require(_royalty <= maxRoyaltyPercentage, "Royalty Percentage Must Be Less Than Or Equal To Max Royalty Percentage");

        listingFixPrices[_token][_tokenId] = listingFixPrice(_price, msg.sender);
        royalties[_token][_tokenId] = royalty(_creator, _royalty);
        emit tokenListedFixPrice(msg.sender, _tokenId, _price);

    }

    function unlistNftFixPrice (address _token, uint256 _tokenId) public {
        require(_token != address(0), "Token address cannot be 0");
        require (IERC721(_token).ownerOf(_tokenId) == msg.sender, "You Dont Own the Given Token");

        delete listingFixPrices[_token][_tokenId];
        delete royalties[_token][_tokenId];
        emit tokenUnlistedFixPrice(msg.sender, _tokenId);
    }

    function buyNftFixedPrice (address _token, uint256 _tokenId) public payable{
        require(_token != address(0), "Token address cannot be 0");
        require(msg.value >= listingFixPrices[_token][_tokenId].price, "You Must Pay At Least The Price");

        uint256 feesToPayOwner = listingFixPrices[_token][_tokenId].price * ownerPercentage / 100;
        uint256 royaltyToPay = listingFixPrices[_token][_tokenId].price * royalties[_token][_tokenId].percentageRoyalty / 100;
        uint256 totalPrice = msg.value - royaltyToPay - feesToPayOwner;
        IERC721(_token).safeTransferFrom(listingFixPrices[_token][_tokenId].seller, msg.sender, _tokenId);
        balanceOf[listingFixPrices[_token][_tokenId].seller] += totalPrice;
        royalties[_token][_tokenId].creator.transfer(royaltyToPay);
        ownerFeesAccount.transfer(feesToPayOwner);
        unlistNftFixPrice(_token, _tokenId);

        emit nftBoughtFixPrice(msg.sender, _tokenId, msg.value);
    }

    function withdraw (uint256 amount, address payable desAdd) public nonReentrant1 {
        require (balanceOf[msg.sender] >= amount, "Insuficient Funds");

        desAdd.transfer(amount);
        balanceOf[msg.sender] -= amount;
    }

    function listNftAuction (uint256 _startPrice, address _token, uint256 _tokenId, address payable _creator, uint256 _royalty, uint256 _timeInSeconds) public {
        require(_token != address(0), "Token address cannot be 0");
        require(_startPrice > 0, "Start Price Must Be Greater Than 0");
        require (IERC721(_token).ownerOf(_tokenId) == msg.sender, "You Dont Own the Given Token");
        require (IERC721(_token).isApprovedForAll(msg.sender, address(this)), "This Contract is not Approved");
        require(_royalty <= maxRoyaltyPercentage, "Royalty Percentage Must Be Less Than Or Equal To Max Royalty Percentage");

        listingAuctions[_token][_tokenId] = listingAuction(_startPrice, msg.sender, _timeInSeconds, block.timestamp + _timeInSeconds);
        royalties[_token][_tokenId] = royalty(_creator, _royalty);
        biddings[_token][_tokenId] = bidding(msg.sender, _startPrice);
        emit tokenListedAuction(msg.sender, _token, _tokenId, _startPrice, block.timestamp + _timeInSeconds);
    }

    function unlistNftAuction (address _token, uint256 _tokenId) public  {
        require(_token != address(0), "Token address cannot be 0");
        require (IERC721(_token).ownerOf(_tokenId) == msg.sender, "You Dont Own the Given Token");
        require((listingAuctions[_token][_tokenId].endTime < block.timestamp), "Auction Has Not Ended");

        delete listingAuctions[_token][_tokenId];
        delete royalties[_token][_tokenId];
        delete biddings[_token][_tokenId];
        emit tokenUnlistedAuction(msg.sender, _token, _tokenId);
    }

    function checkAuctionEndTime (address _token, uint256 _tokenId) public view {
        require(_token != address(0), "Token address cannot be 0");
        require (IERC721(_token).ownerOf(_tokenId) == msg.sender, "You Dont Own the Given Token");
        require((listingAuctions[_token][_tokenId].endTime < block.timestamp), "Auction Has Not Ended");
    }

    function checkNftStatus (address _token, uint256 _tokenId) public view returns (address, uint256) {
        require(listingAuctions[_token][_tokenId].endTime > block.timestamp, "Auction Has Ended");
        require(_token != address(0), "Token address cannot be 0");
        return (biddings[_token][_tokenId].Highestbidder, biddings[_token][_tokenId].currentPrice);
    }

    function bidOnNft (address _token, uint256 _tokenId, uint256 _biddingPrice) public payable {
        require(_token != address(0), "Token address cannot be 0");
        require(msg.value >= _biddingPrice, "You Must Pay At Least The Price");
        require(_biddingPrice > biddings[_token][_tokenId].currentPrice, "Bidding Price should be greater than the Current Bid");
        require(listingAuctions[_token][_tokenId].endTime > block.timestamp, "Auction Has Ended");
        require(biddings[_token][_tokenId].Highestbidder != msg.sender, "You Have Already Highest Bidder On This Token");

        balanceOf[biddings[_token][_tokenId].Highestbidder] += biddings[_token][_tokenId].currentPrice;
        biddings[_token][_tokenId].Highestbidder = msg.sender;
        biddings[_token][_tokenId].currentPrice = _biddingPrice;

        emit nftBiddedOnAuction(msg.sender, _token, _tokenId, _biddingPrice);

    }

    function withdrawAuction (address _token, uint256 _tokenId) public {
        require(_token != address(0), "Token address cannot be 0");
        require((listingAuctions[_token][_tokenId].endTime < block.timestamp), "Auction Has Not Ended");
        require(biddings[_token][_tokenId].Highestbidder == msg.sender, "You Are Not The Highest Bidder On This Token");

        uint256 feesToPayOwner = biddings[_token][_tokenId].currentPrice * ownerPercentage / 100;
        uint256 royaltyToPay = biddings[_token][_tokenId].currentPrice * royalties[_token][_tokenId].percentageRoyalty / 100;
        uint256 totalPrice = biddings[_token][_tokenId].currentPrice - royaltyToPay - feesToPayOwner;
        IERC721(_token).safeTransferFrom(listingAuctions[_token][_tokenId].seller, msg.sender, _tokenId);
        balanceOf[listingAuctions[_token][_tokenId].seller] += totalPrice;
        royalties[_token][_tokenId].creator.transfer(royaltyToPay);
        ownerFeesAccount.transfer(feesToPayOwner);
        unlistNftAuction(_token, _tokenId);

        emit nftWithdrawnAuction(msg.sender, _token, _tokenId, biddings[_token][_tokenId].currentPrice);
    }
}
