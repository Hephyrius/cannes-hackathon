@echo off
echo 🚀 DEPLOYING TO FLOW NETWORK 🚀
echo ================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📡 Network: Flow EVM
echo 💰 USDC Address: 0xF1815bd50389c46847f0Bda824eC8da914045D14
echo 🔗 RPC: https://mainnet.evm.nodes.onflow.org
echo 🆔 Chain ID: 747
echo.

REM Prompt for private key
set /p PRIVATE_KEY=Enter your private key (without 0x prefix): 

echo.
echo 📦 Deploying prediction market to Flow...
echo.

REM Deploy to Flow
%USERPROFILE%\.foundry\bin\forge script script/FlowDeploy.s.sol:FlowDeployScript --rpc-url https://mainnet.evm.nodes.onflow.org --broadcast --private-key %PRIVATE_KEY% --verify --etherscan-api-key %FLOWSCAN_API_KEY% -vvv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed!
    echo Common issues:
    echo - Insufficient FLOW balance for gas fees
    echo - Invalid private key
    echo - Network connectivity issues
    echo - Check that you have FLOW tokens for gas
    pause
    exit /b 1
)

echo.
echo ✅ Successfully deployed to Flow!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Save the contract addresses from the output above
echo 2. Add Flow network to your wallet if not already added
echo 3. Get USDC on Flow from:
echo    - Bridge from other networks
echo    - Buy on Flow DEX
echo    - Centralized exchange withdrawal
echo 4. Start testing with minimum amounts (0.000001 USDC)
echo.
echo 🌟 Your prediction market is live on Flow!
echo.
echo 📚 Resources:
echo - Flow Portal: https://port.onflow.org
echo - Flow Explorer: https://evm.flowscan.org  
echo - Flow Docs: https://developers.flow.com
echo - Flow Discord: https://discord.gg/flow
echo.
echo 🎮 Demo Market: "Will Flow reach $10 by end of 2024?"
echo Ready for hackathon demos with 1-minute phases!
echo.
pause 