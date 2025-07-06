@echo off
echo 🚀 PREDICTION MARKET DEPLOYMENT (Windows) 🚀
echo =============================================

REM Check if we're in the right directory
if not exist "foundry.toml" (
    echo ❌ Error: Not in contracts directory. Please run from contracts\ folder
    pause
    exit /b 1
)

echo 📦 Deploying contracts to persistent Anvil...
echo.

REM Deploy contracts to running Anvil
%USERPROFILE%\.foundry\bin\forge script script/LocalDeploy.s.sol:LocalDeployScript --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vv

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deployment failed. Make sure Anvil is running on localhost:8545
    echo    Run: start_anvil.bat in a separate terminal first
    pause
    exit /b 1
)

echo.
echo ✅ Contracts deployed successfully!
echo.
echo 🎯 NEXT STEPS:
echo ==============
echo 1. Keep Anvil running (don't close the Anvil terminal)
echo 2. Use these addresses in your UI:
echo    - RPC URL: http://localhost:8545
echo    - Chain ID: 31337
echo 3. Connect wallet with these test accounts:
echo    - Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
echo    - LP1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
echo    - LP2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
echo    - Trader: 0x90F79bf6EB2c4f870365E785982E1f101E93b906
echo.
echo 🌟 Ready for UI testing!
pause 