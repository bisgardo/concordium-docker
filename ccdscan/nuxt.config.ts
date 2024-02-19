import { defineNuxtConfig } from 'nuxt3'

export default defineNuxtConfig({
	srcDir: 'src/',
	components: [
		'~/components',
		'~/components/atoms',
		'~/components/molecules',
		'~/components/icons',
		'~/components/Table',
		'~/components/Drawer',
		'~/components/BlockDetails',
	],
	publicRuntimeConfig: {
		apiUrl: 'http://localhost:5000/graphql',
		wsUrl: 'ws://localhost:5000/graphql',
		environment: 'dev', // enables some error reporting or something
		includeDevTools: true,
	},
	nitro: {
		// Should be "node-server", but that doesn't work with the current dependency versions
		// (getting error "Cannot resolve preset: node-server" - see 'https://forum.cleavr.io/t/cannot-resolve-node-server-preset/686').
		preset: '',
	},
	css: ['@/assets/css/styles.css'],
	build: {
		postcss: {
			postcssOptions: require('./postcss.config.cjs'),
		},
	},
})
