const hre = require("hardhat");
const upgrades = hre.upgrades;

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", hre.ethers.utils.formatEther(await deployer.provider.getBalance(deployer.address)));

  // 1. Deploy Rewards (regular deploy)
  const Rewards = await hre.ethers.getContractFactory("Rewards");
  const rewards = await Rewards.deploy(deployer.address);
  await rewards.deployed();
  const rewardsAddr = rewards.address;
  console.log("Rewards:", rewardsAddr);

  // 2. Deploy NFT (regular deploy)
  const CrossRealmNFT = await hre.ethers.getContractFactory("CrossRealmNFT");
  const nft = await CrossRealmNFT.deploy();
  await nft.deployed();
  const nftAddr = nft.address;
  console.log("NFT:", nftAddr);

  // 3. Deploy Staking (regular deploy)
  const CORE_ADDR = "0x0000000000000000000000000000000000000000"; // Native CORE
  const Staking = await hre.ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(CORE_ADDR, CORE_ADDR);
  await staking.deployed();
  const stakingAddr = staking.address;
  console.log("Staking:", stakingAddr);

  // 4. Deploy Verifiers (regular deploy)
  const ChessVerifier = await hre.ethers.getContractFactory("ChessVerifier");
  const chessVerifier = await ChessVerifier.deploy();
  await chessVerifier.deployed();
  const chessAddr = chessVerifier.address;
  console.log("ChessVerifier:", chessAddr);

  const CheckersVerifier = await hre.ethers.getContractFactory("CheckersVerifier");
  const checkersVerifier = await CheckersVerifier.deploy();
  await checkersVerifier.deployed();
  const checkersAddr = checkersVerifier.address;
  console.log("CheckersVerifier:", checkersAddr);

  // 5. Deploy Hub (upgradeable proxy)
  const Hub = await hre.ethers.getContractFactory("Hub");
  const hub = await upgrades.deployProxy(Hub, [rewardsAddr, nftAddr], { initializer: "initialize" });
  await hub.deployed();
  const hubAddr = hub.address;
  console.log("Hub:", hubAddr);

  // 6. Set Hub in Rewards
  const rewardsContract = Rewards.attach(rewardsAddr);
  await (await rewardsContract.setHub(hubAddr)).wait();
  console.log("Hub set in Rewards");

  // 7. Register Verifiers in Hub
  const hubContract = Hub.attach(hubAddr);
  await (await hubContract.registerVerifier("chess", chessAddr)).wait();
  console.log("Chess verifier registered");
  await (await hubContract.registerVerifier("checkers", checkersAddr)).wait();
  console.log("Checkers verifier registered");

  // 8. Verify (optional)
  console.log("\nVerifying...");
  try {
    await hre.run("verify:verify", { address: rewardsAddr, constructorArguments: [deployer.address] });
  } catch (e) { console.log("Rewards skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: nftAddr });
  } catch (e) { console.log("NFT skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: stakingAddr, constructorArguments: [CORE_ADDR, CORE_ADDR] });
  } catch (e) { console.log("Staking skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: chessAddr });
  } catch (e) { console.log("ChessVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: checkersAddr });
  } catch (e) { console.log("CheckersVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: hubAddr, constructorArguments: [rewardsAddr, nftAddr] });
  } catch (e) { console.log("Hub skip:", e.message); }

  console.log("\nFull deployment complete! Update index.html with:");
  console.log(`HUB_ADDRESS = '${hubAddr}';`);
  console.log(`REWARDS_ADDRESS = '${rewardsAddr}';`);
  console.log(`NFT_ADDRESS = '${nftAddr}';`);
  console.log(`STAKING_ADDRESS = '${stakingAddr}';`);
  console.log(`VERIFIER_ADDRESSES = { chess: '${chessAddr}', checkers: '${checkersAddr}', fighting: '0x0000000000000000000000000000000000000000', carrace: '0x0000000000000000000000000000000000000000', soccerpenalty: '0x0000000000000000000000000000000000000000', snooker: '0x0000000000000000000000000000000000000000' };`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});