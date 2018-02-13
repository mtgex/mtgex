pragma solidity ^0.4.17;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';
import './Card.sol';

contract MTGEX is Ownable, HasNoEther {
  event CardAdded(string mtgexId);
  event CardsMinted(string mtgexId, address addr, uint256 amount);
  event RedemptionRequested(string mtgexId, address addr, uint256 amount);
  event RedemptionReceived(string mtgexId, address addr, uint256 amount, string secret);
  event RedemptionConfirmed(string mtgexId, address addr, uint256 amount);
  event RedemptionRejected(string mtgexId, address addr, uint256 amount);
  event RedemptionCancelled(string mtgexId, address addr, uint256 amount);

  /**
  * A mapping of our own "mtgexId" to Card contracts.
  */
  mapping(bytes32 => Card) cards;

  /**
  * A mapping of "mtgexId" to Redemptions for that Card.
  */
  mapping(bytes32 => mapping(address => Redemption)) redemptionQueue;

  struct Redemption {
    string mtgexId;
    address addr;
    uint256 amount;
    string secret;
  }

  /**
  * Constructor, nothing really to see here...
  */
  function MTGEX() public {
    //
  }

  /**
  * A contract factory that allows this contract owner to create an arbitrary token contract.
  * @param _mtgjsonId the id provided by the wonderful mtgjson.com
  * @param _foil whether the card is foil or not
  * @param _condition the condition (nm, pl, hp). As damaged cards are not at all fungible, those have been excluded
  */
  function createCardContract(string _mtgjsonId, bool _foil, string _condition) public onlyOwner {
    string memory mtgexId = getMtgexId(_mtgjsonId, _foil, _condition);
    Card card = cards[keccak256(mtgexId)];
    require(false == cardExists(card));
    card = new Card(mtgexId, _mtgjsonId, _foil, _condition);
    cards[keccak256(mtgexId)] = card;
    CardAdded(mtgexId);
  }

  /**
  * Constructs a unique id for a Card from its properties: condition, foil or non foil, mtgjsonId
  * Format is {nm|pl|hp}_{fl|nf}_mtgjsonId
  */
  function getMtgexId(string _mtgjsonId, bool _foil, string _condition) internal pure returns (string mtgexId) {
    return strConcat(_condition, _foil ? "_fl_" : "_nf_", _mtgjsonId);
  }

  /**
  * String concatenation function.
  */
  function strConcat(string _a, string _b, string _c) internal pure returns (string){
      bytes memory _ba = bytes(_a);
      bytes memory _bb = bytes(_b);
      bytes memory _bc = bytes(_c);
      string memory abc = new string(_ba.length + _bb.length + _bc.length);
      bytes memory babc = bytes(abc);
      uint k = 0;
      for (uint i = 0; i < _ba.length; i++) babc[k++] = _ba[i];
      for (i = 0; i < _bb.length; i++) babc[k++] = _bb[i];
      for (i = 0; i < _bc.length; i++) babc[k++] = _bc[i];
      return string(babc);
  }

  /**
  * Mints tokens for a specific Card and gives them to a specific address.
  * @param _mtgexId the mtgex identifier for the Card
  * @param _to the wallet address to give the tokens to
  * @param _amount the amount of tokens to mint, as an integer
  */
  function mintTokens(string _mtgexId, address _to, uint256 _amount) public onlyOwner {
    require(_amount > 0);
    Card card = cards[keccak256(_mtgexId)];
    require(cardExists(card));
    card.mint(_to, _amount * 1000000000000000000);
    CardsMinted(_mtgexId, _to, _amount);
  }

  /**
  * Step 1 of 3 (token user)
  * Initiates the redemption process for the calling user for the given mtgexId and amount.
  * @param _mtgexId the mtgex identifier for the Card
  * @param _amount the amount of tokens to redeem for physical cards
  */
  function initiateRedemption(string _mtgexId, uint256 _amount) public {
    require(redemptionExists(redemptionQueue[keccak256(_mtgexId)][msg.sender]) == false);
    Card card = cards[keccak256(_mtgexId)];
    require(cardExists(card));
    require(_amount > 0);
    require(card.balanceOf(msg.sender) >= _amount * 1000000000000000000);
    card.burn(msg.sender, _amount * 1000000000000000000);
    redemptionQueue[keccak256(_mtgexId)][msg.sender] = Redemption({mtgexId: _mtgexId, addr: msg.sender, amount: _amount, secret:""});
    RedemptionRequested(_mtgexId, msg.sender, _amount);
  }

  /**
  * Step 2 of 3 (contract owner)
  * Called by the contract owner when a redemption form is received in the mail.
  *
  * @param _mtgexId the mtgex identifier for the Card
  * @param _from the wallet address provided on the redemption form
  * @param _secret the secret passcode provided on the redemption form.  Obviously this is no longer secret after calling this function.
  *                This allows the token redeemer to confirm that the redemption form received is the one they sent.
  */
  function receiveRedemption(string _mtgexId, address _from, string _secret) public onlyOwner {
    Redemption storage redemption = redemptionQueue[keccak256(_mtgexId)][_from];
    require(redemptionExists(redemption));
    require(bytes(redemption.secret).length == 0);
    redemption.secret = _secret;
    RedemptionReceived(redemption.mtgexId, redemption.addr, redemption.amount, redemption.secret);
  }

  /**
  * Step 3 of 3 (token user)
  * Called by the token redeemer if the secret assigned by receiveRedemption() matches the secret on their mail in form.
  *
  * @param _mtgexId the mtgex identifier for the Card
  * @param _secret a confirmation of the secret passcode
  */
  function confirmReceivedRedemption(string _mtgexId, string _secret) public {
    Redemption storage redemption = redemptionQueue[keccak256(_mtgexId)][msg.sender];
    require(redemptionExists(redemption));
    require(redemption.addr == msg.sender);
    require(bytes(redemption.secret).length != 0);
    require(keccak256(redemption.secret) == keccak256(_secret));
    RedemptionConfirmed(redemption.mtgexId, redemption.addr, redemption.amount);
    delete(redemptionQueue[keccak256(redemption.mtgexId)][msg.sender]);
  }

  /**
  * Step 3 of 3 (token user)
  * Called by the token redeemer if the secret assigned by receiveRedemption() DOES NOT MATCH the secret on their mail in form.
  * The secret is cleared and the contract owner will simply wait for the true redemption request to arrive in the mail.
  * @param _mtgexId the mtgex identifier for the Card
  */
  function rejectReceivedRedemption(string _mtgexId) public {
    Redemption storage redemption = redemptionQueue[keccak256(_mtgexId)][msg.sender];
    require(redemptionExists(redemption));
    require(redemption.addr == msg.sender);
    redemption.secret = "";
    RedemptionRejected(redemption.mtgexId, redemption.addr, redemption.amount);
  }

  /**
  * Cancels a pending redemption and returns the tokens to the user.
  * @param _mtgexId the mtgex identifier for the Card
  */
  function cancelRedemption(string _mtgexId) public {
    Redemption storage redemption = redemptionQueue[keccak256(_mtgexId)][msg.sender];
    require(redemptionExists(redemption));
    require(bytes(redemption.secret).length == 0);

    Card card = cards[keccak256(redemption.mtgexId)];
    card.mint(msg.sender, redemption.amount * 1000000000000000000);
    CardsMinted(redemption.mtgexId, msg.sender, redemption.amount);

    RedemptionCancelled(redemption.mtgexId, redemption.addr, redemption.amount);
    delete(redemptionQueue[keccak256(redemption.mtgexId)][msg.sender]);
  }

  function cardExists(Card _card) internal pure returns (bool exists) {
    return address(_card) != 0;
  }

  function redemptionExists(Redemption _redemption) internal pure returns (bool exists) {
    return bytes(_redemption.mtgexId).length > 0;
  }

  function getCardTokenAddress(string _mtgexId) public view returns (address addr) {
    Card card = cards[keccak256(_mtgexId)];
    require(cardExists(card));
    return address(card);
  }

  function getMyRedemptionDetails(string _mtgexId) public view returns (uint256 amount, string secret) {
    Redemption storage redemption = redemptionQueue[keccak256(_mtgexId)][msg.sender];
    require(redemptionExists(redemption));
    return (redemption.amount, redemption.secret);
  }

}
