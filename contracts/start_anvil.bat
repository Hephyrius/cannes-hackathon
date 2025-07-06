@echo off
echo 🔧 STARTING ANVIL LOCAL BLOCKCHAIN 🔧
echo =====================================
echo.
echo 📡 Network Details:
echo   - RPC URL: http://localhost:8545
echo   - Chain ID: 31337
echo   - Block time: Instant
echo.
echo 🏦 Pre-funded Test Accounts:
echo   Account 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10,000 ETH)
echo   Account 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10,000 ETH)
echo   Account 2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10,000 ETH)
echo   Account 3: 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (10,000 ETH)
echo.
echo 🔑 Private Keys:
echo   Key 0: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
echo   Key 1: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
echo   Key 2: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
echo   Key 3: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
echo.
echo ⚡ Starting Anvil... (Keep this terminal open)
echo    Press Ctrl+C to stop the blockchain
echo.

%USERPROFILE%\.foundry\bin\anvil --host 0.0.0.0 --port 8545 