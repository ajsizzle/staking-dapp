require("@nomiclabs/hardhat-waffle")
require("hardhat-deploy")

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.7",
    namedAccounts: {
        deployer: {
            default: 0, // ethers built in account at index 0
        },
    },
}
