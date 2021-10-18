import "@nomiclabs/hardhat-waffle";
import "hardhat-gas-reporter";
import "hardhat-typechain";
import "@nomiclabs/hardhat-etherscan";
import '@openzeppelin/hardhat-upgrades';
import "solidity-coverage";
import "hardhat-spdx-license-identifier";
import "hardhat-tracer";
import "hardhat-docgen";


// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
module.exports = {
    // This is a sample solc configuration that specifies which version of solc to use
    solidity: {
        compilers:[
            {
                version: "0.6.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: true,
                            yulDetails: {
                                stackAllocation: true,
                            }
                        }
                    }
                }
            },
            {
                version: "0.7.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.8.2",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.8.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.4.13",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.5.16",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            }
        ],
    },
    networks: {
        bsc_testnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            chainId: 97,
            gasPrice: 20000000000
        },
        bsc_mainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: 20000000000
        }
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v5",
        runOnCompile: true
    },
    gasReporter: {
        enabled: false,
        currency: 'CNY'
    },
    mocha: {
        timeout: 2000000,
    },
    paths: {
      tests: './test/case/'
    },
    etherscan: {
        apiKey: "<YOUR API KEY>"

    },
    spdxLicenseIdentifier: {
        overwrite: true,
        runOnCompile: true,
    },
    docgen: {
        path: './docs/contracts',
        clear: true,
        runOnCompile: false,
        except: ['^contracts/interfaces', '^contracts/Proxy', '^contracts/test']
    }
};
