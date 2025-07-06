@echo off
echo 🚀 DEPLOYING TO FLOW TESTNET 🚀
echo =================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📡 Network: Flow Testnet
echo 💰 USDF Address: 0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F
echo 🔗 RPC: https://testnet.evm.nodes.onflow.org
echo 🆔 Chain ID: 545
echo.

REM Prompt for private key
set /p PRIVATE_KEY=Enter your private key (without 0x prefix): 

echo.
echo 📦 Deploying prediction market to Flow Testnet...
echo.

REM Deploy to Flow Testnet
%USERPROFILE%\.foundry\bin\forge script script/FlowDeploy.s.sol:FlowTestnetDeployScript --rpc-url https://testnet.evm.nodes.onflow.org --broadcast --private-key %PRIVATE_KEY% --verify --etherscan-api-key %FLOWSCAN_API_KEY% -vvv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed!
    echo Common issues:
    echo - Insufficient testnet FLOW balance for gas fees
    echo - Invalid private key
    echo - Network connectivity issues
    echo - Get testnet FLOW tokens from faucet first
    pause
    exit /b 1
)

echo.
echo ✅ Successfully deployed to Flow Testnet!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Save the contract addresses from the output above
echo 2. Add Flow testnet to your wallet if not already added
echo 3. Get USDF tokens for testing:
echo    - Contract: 0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F
echo    - 18 decimals (different from 6-decimal USDC)
echo    - Get from testnet faucet or bridge
echo 4. Start testing with minimum amounts (0.000001 USDF)
echo.
echo 🌟 Your prediction market is live on Flow Testnet!
echo.
echo 📚 Resources:
echo - Flow Testnet Faucet: https://testnet-faucet.onflow.org
echo - Flow Testnet Explorer: https://testnet.flowscan.org
echo - Flow Docs: https://developers.flow.com
echo - Flow Discord: https://discord.gg/flow
echo.
echo 🎮 Demo Market: "Will Flow reach $10 by end of 2024?"
echo Ready for hackathon demos with 1-minute phases!
echo.
pause 