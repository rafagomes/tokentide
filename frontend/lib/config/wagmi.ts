import { mainnet, scroll, base, optimism, arbitrum, polygon } from 'viem/chains'
import { cookieStorage, createConfig, createStorage, http } from 'wagmi'

export default createConfig({
    chains: [mainnet, base, scroll, optimism, arbitrum, polygon],
    ssr: true,
    storage: createStorage({
        storage: cookieStorage,
    }),
    transports: {
        [mainnet.id]: http(),
        [base.id]: http(),
        [scroll.id]: http(),
        [optimism.id]: http(),
        [arbitrum.id]: http(),
        [polygon.id]: http(),
    },
})
