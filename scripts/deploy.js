const hre = require("hardhat");
const { ethers } = hre;
const upgrades = hre.upgrades;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", ethers.utils.formatEther(await deployer.provider.getBalance(deployer.address)));

  const NATIVE_TOKEN = "0x0000000000000000000000000000000000000000"; // Native CORE

  // 1. Deploy Rewards (regular deploy, v5 style)
  const Rewards = await ethers.getContractFactory("Rewards");
  const deployTxRewards = await Rewards.deploy(deployer.address, NATIVE_TOKEN); // New: 2 args (_dev, _staking native)
  const rewards = await deployTxRewards.deployed();
  const rewardsAddr = rewards.address;
  console.log("Rewards:", rewardsAddr);

  // 2. Deploy NFT
  const CrossRealmNFT = await ethers.getContractFactory("CrossRealmNFT");
  const deployTxNFT = await CrossRealmNFT.deploy();
  const nft = await deployTxNFT.deployed();
  const nftAddr = nft.address;
  console.log("NFT:", nftAddr);

  // 3. Deploy Staking (native CORE for both)
  const Staking = await ethers.getContractFactory("Staking");
  const deployTxStaking = await Staking.deploy(NATIVE_TOKEN, NATIVE_TOKEN);
  const staking = await deployTxStaking.deployed();
  const stakingAddr = staking.address;
  console.log("Staking:", stakingAddr);

  // 4. Deploy Verifiers
  const ChessVerifier = await ethers.getContractFactory("ChessVerifier");
  const deployTxChess = await ChessVerifier.deploy();
  const chessVerifier = await deployTxChess.deployed();
  const chessAddr = chessVerifier.address;
  console.log("ChessVerifier:", chessAddr);

  const CheckersVerifier = await ethers.getContractFactory("CheckersVerifier");
  const deployTxCheckers = await CheckersVerifier.deploy();
  const checkersVerifier = await deployTxCheckers.deployed();
  const checkersAddr = checkersVerifier.address;
  console.log("CheckersVerifier:", checkersAddr);

  // 5. NEW: Deploy Tournament
  const Tournament = await ethers.getContractFactory("Tournament");
  const deployTxTournament = await Tournament.deploy(NATIVE_TOKEN, NATIVE_TOKEN); // Hub stub as native
  const tournament = await deployTxTournament.deployed();
  const tournamentAddr = tournament.address;
  console.log("Tournament:", tournamentAddr);

  // 6. Deploy Hub (proxy—upgrades handles v5)
  const Hub = await ethers.getContractFactory("Hub");
  const hub = await upgrades.deployProxy(Hub, [rewardsAddr, nftAddr], { initializer: "initialize" });
  await hub.deployed(); // v5 for proxy
  const hubAddr = hub.address;
  console.log("Hub:", hubAddr);

  // 7. Set Hub in Rewards
  const rewardsContract = await ethers.getContractAt("Rewards", rewardsAddr);
  await (await rewardsContract.setHub(hubAddr)).wait();
  console.log("Hub set in Rewards");

  // 8. Register Verifiers in Hub
  const hubContract = await ethers.getContractAt("Hub", hubAddr);
  await (await hubContract.registerVerifier("chess", chessAddr)).wait();
  console.log("Chess verifier registered");
  await (await hubContract.registerVerifier("checkers", checkersAddr)).wait();
  console.log("Checkers verifier registered");

  // 9. Verify (optional, with skips)
  console.log("\nVerifying...");
  try {
    await hre.run("verify:verify", { address: rewardsAddr, constructorArguments: [deployer.address] });
  } catch (e) { console.log("Rewards skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: nftAddr });
  } catch (e) { console.log("NFT skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: stakingAddr, constructorArguments: [NATIVE_TOKEN, NATIVE_TOKEN] });
  } catch (e) { console.log("Staking skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: chessAddr });
  } catch (e) { console.log("ChessVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: checkersAddr });
  } catch (e) { console.log("CheckersVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: tournamentAddr, constructorArguments: [NATIVE_TOKEN, NATIVE_TOKEN] });
  } catch (e) { console.log("Tournament skip:", e.message); }
  // Hub proxy impl
  const implAddr = await upgrades.erc1967.getImplementationAddress(hubAddr);
  try {
    await hre.run("verify:verify", { address: implAddr });
  } catch (e) { console.log("Hub impl skip:", e.message); }

  console.log("\nFull deployment complete! Update index.html with:");
  console.log(`HUB_ADDRESS = '${hubAddr}';`);
  console.log(`REWARDS_ADDRESS = '${rewardsAddr}';`);
  console.log(`NFT_ADDRESS = '${nftAddr}';`);
  console.log(`STAKING_ADDRESS = '${stakingAddr}';`);
  console.log(`TOURNAMENT_ADDRESS = '${tournamentAddr}';`); // NEW
  console.log(`VERIFIER_ADDRESSES = { chess: '${chessAddr}', checkers: '${checkersAddr}', fighting: '0x0000000000000000000000000000000000000000', carrace: '0x0000000000000000000000000000000000000000' };`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});