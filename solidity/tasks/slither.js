const { task } = require('hardhat/config');
const execSync = require('child_process').execSync;

task('slither', 'Run Slither analysis on Solidity contracts')
    .addOptionalParam('contract', 'The contract name to analyze')
    .setAction(async ({ contract }) => {
        const baseCommand = `slither ./contracts`;

        const command = contract
            ? `${baseCommand}/${contract}.sol`
            : baseCommand;

        try {
            execSync(command, { stdio: 'inherit' });
        } catch (error) {
            console.error('Slither analysis failed:', error.message);
        }
    });
