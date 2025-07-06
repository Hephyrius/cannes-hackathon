@echo off
echo 🚀 DEPLOYING TO MANTLE NETWORK 🚀
echo ==================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📡 Network: Mantle
echo 💰 USDC Address: 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9
echo 🔗 RPC: https://rpc.mantle.xyz
echo 🆔 Chain ID: 5000
echo.

REM Prompt for private key
set /p PRIVATE_KEY=Enter your private key (without 0x prefix): 

echo.
echo 📦 Deploying prediction market to Mantle...
echo.

REM Deploy to Mantle
%USERPROFILE%\.foundry\bin\forge script script/MantleDeploy.s.sol:MantleDeployScript --rpc-url https://rpc.mantle.xyz --broadcast --private-key %PRIVATE_KEY% --verify --etherscan-api-key %MANTLESCAN_API_KEY% -vvv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed!
    echo Common issues:
    echo - Insufficient MNT balance for gas fees
    echo - Invalid private key
    echo - Network connectivity issues
    echo - Check that you have MNT for gas
    pause
    exit /b 1
)

echo.
echo ✅ Successfully deployed to Mantle!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Save the contract addresses from the output above
echo 2. Add Mantle network to your wallet if not already added
echo 3. Get USDC on Mantle from:
echo    - Bridge from Ethereum
echo    - Buy on Mantle DEX
echo    - Centralized exchange withdrawal
echo 4. Start testing with minimum amounts (0.000001 USDC)
echo.
echo 🌟 Your prediction market is live on Mantle!
echo.
echo 📚 Resources:
echo - Mantle Bridge: https://bridge.mantle.xyz
echo - Mantle Explorer: https://explorer.mantle.xyz
echo - Mantle Docs: https://docs.mantle.xyz
echo.
pause 