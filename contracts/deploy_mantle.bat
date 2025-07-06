@echo off
echo 🚀 DEPLOYING TO MANTLE TESTNET 🚀
echo ==================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📡 Network: Mantle Testnet
echo 💰 Test USDC: Will be deployed (18 decimals)
echo 🔗 RPC: https://rpc.testnet.mantle.xyz
echo 🆔 Chain ID: 5001
echo.

REM Prompt for private key
set /p PRIVATE_KEY=Enter your private key (without 0x prefix): 

echo.
echo 📦 Deploying prediction market to Mantle Testnet...
echo.

REM Deploy to Mantle Testnet
%USERPROFILE%\.foundry\bin\forge script script/MantleTestnetDeploy.s.sol:MantleTestnetDeployScript --rpc-url https://rpc.testnet.mantle.xyz --broadcast --private-key %PRIVATE_KEY% --verify --etherscan-api-key %MANTLESCAN_API_KEY% -vvv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed!
    echo Common issues:
    echo - Insufficient testnet MNT balance for gas fees
    echo - Invalid private key
    echo - Network connectivity issues
    echo - Get testnet MNT from faucet first
    pause
    exit /b 1
)

echo.
echo ✅ Successfully deployed to Mantle Testnet!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Save the contract addresses from the output above
echo 2. Add Mantle testnet to your wallet if not already added
echo 3. Get test USDC from the deployed contract:
echo    - Use faucet() function to get 1000 test USDC
echo    - Contract has 18 decimals
echo    - Millions of tokens available for testing
echo 4. Start testing with minimum amounts (0.000001 Test USDC)
echo.
echo 🌟 Your prediction market is live on Mantle Testnet!
echo.
echo 📚 Resources:
echo - Mantle Testnet Explorer: https://explorer.testnet.mantle.xyz
echo - Mantle Testnet Faucet: https://faucet.testnet.mantle.xyz
echo - Mantle Docs: https://docs.mantle.xyz
echo.
pause 