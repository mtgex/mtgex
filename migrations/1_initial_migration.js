//var Migrations = artifacts.require("./Migrations.sol");
var MTGEX = artifacts.require("./MTGEX.sol");

module.exports = function(deployer) {
  //deployer.deploy(Migrations)
  deployer.deploy(MTGEX);
};
