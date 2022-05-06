const { network, ethers, deployments } = require("hardhat")
const { moveBlocks } = require("../utils/move-blocks")
const { moveTime } = require("../utils/move-time")

const SECONDS_IN_A_DAY = 86400

describe("Staking Test", async function () {
    let staking, rewardToken, deployer, stakeAmount

    beforeEach(async function () {
        const accounts = await ethers.getSigners()
        deployer = await accounts[0]

        await deployments.fixture(["rewardtoken", "staking"]) // deploys contracts
        staking = await ethers.getContract("Staking")
        rewardToken = await ethers.getContract("RewardToken")
        stakeAmount = ethers.utils.parseEther("100000")
    })

    it("Should allow users to stake and claim rewards", async function () {
        await rewardToken.approve(staking.address, stakeAmount)
        await staking.stake(stakeAmount) // 100000 tokens
        const startingEarned = await staking.earned(deployer.address)
        console.log(`Starting Earned ${startingEarned} tokens`)

        await moveTime(SECONDS_IN_A_DAY)
        await moveBlocks(1)
        const endingEarned = await staking.earned(deployer.address)
        console.log(`Ending Earned ${endingEarned} tokens`)
    })
})
