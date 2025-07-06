@echo off
echo 🚀 DEPLOYING TO BASE NETWORK 🚀
echo =================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📡 Network: Base
echo 💰 USDC Address: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
echo 🔗 RPC: https://mainnet.base.org
echo 🆔 Chain ID: 8453
echo.

REM Prompt for private key
set /p PRIVATE_KEY=Enter your private key (without 0x prefix): 

echo.
echo 📦 Deploying prediction market to Base...
echo.

REM Deploy to Base
%USERPROFILE%\.foundry\bin\forge script script/BaseDeploy.s.sol:BaseDeployScript --rpc-url https://mainnet.base.org --broadcast --private-key %PRIVATE_KEY% --verify --etherscan-api-key %BASESCAN_API_KEY% -vvv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed!
    echo Common issues:
    echo - Insufficient ETH balance for gas fees
    echo - Invalid private key
    echo - Network connectivity issues
    echo - Check that you have Base ETH for gas
    pause
    exit /b 1
)

echo.
echo ✅ Successfully deployed to Base!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Save the contract addresses from the output above
echo 2. Add Base network to your wallet if not already added
echo 3. Get USDC on Base from:
echo    - Bridge from Ethereum
echo    - Buy on Base DEX
echo    - Centralized exchange withdrawal
echo 4. Start testing with minimum amounts (0.000001 USDC)
echo.
echo 🌟 Your prediction market is live on Base!
echo.
echo 📚 Resources:
echo - Base Bridge: https://bridge.base.org
echo - Base Explorer: https://basescan.org
echo - Base Docs: https://docs.base.org
echo.
pause 