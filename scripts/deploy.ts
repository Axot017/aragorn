// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Greeter = await ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("Hello, Hardhat!");

  await greeter.deployed();

  const MyArbitrage = await ethers.getContractFactory("MyArbitrage");
  const myArbitrage = await MyArbitrage.deploy(
    "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5",
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    "0x833e4083B7ae46CeA85695c4f7ed25CDAd8886dE",
    "0x1c87257f5e8609940bc751a07bb085bb7f8cdbe6",
    "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"
  );
  const contract = await myArbitrage.deployed();
  await contract.arbitrage(
    ["SUSHISPWAP", "UNISWAP"],
    [
      "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    ],
    "230000000000000000000"
  );

  console.log("Greeter deployed to:", greeter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
