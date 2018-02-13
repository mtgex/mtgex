pragma solidity ^0.4.17;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import 'zeppelin-solidity/contracts/token/BurnableToken.sol';
import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';

contract Card is MintableToken, BurnableToken, HasNoEther {

  uint8 public decimals = 18;
  string public symbol = "mtgex.io";
  string public name; // mtgexId
  string public mtgjsonId;
  bool public foil;
  string public condition;

  function Card(string _mtgexId, string _mtgjsonId, bool _foil, string _condition) public {
    require(areEqual(_condition, "nm") || areEqual(_condition, "pl") || areEqual(_condition, "hp"));
    name = _mtgexId;
    mtgjsonId = _mtgjsonId;
    foil = _foil;
    condition = _condition;
  }

  function areEqual(string a, string b) internal pure returns (bool){
    return keccak256(a) == keccak256(b);
  }

  /**
   * @dev Burns a specific amount of tokens.
   * Lifted from BurnableToken.sol, but allows the MTGEX
   * contract owner to burn tokens at any given address.
   * @param _burner The address to burn from.
   * @param _value The amount of token to be burned.
   */
  function burn(address _burner, uint256 _value) public onlyOwner {
      require(_value > 0);
      require(_value <= balances[_burner]);
      // no need to require value <= totalSupply, since that would imply the
      // sender's balance is greater than the totalSupply, which *should* be an assertion failure

      balances[_burner] = balances[_burner].sub(_value);
      totalSupply = totalSupply.sub(_value);
      Burn(_burner, _value);
  }

  /**
   * Overriding standard burn method to disallow users to burn their own tokens.
   */
  function burn(uint256 _value) public onlyOwner {
    require(false);
  }

}
