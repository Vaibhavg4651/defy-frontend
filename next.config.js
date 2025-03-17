const withMDX = require('@next/mdx')({
  extension: /\.mdx?$/,
  options: {
    remarkPlugins: [],
    rehypePlugins: [],
  },
})

// Try to load code-inspector-plugin, but make it optional
let codeInspectorPlugin;
try {
  codeInspectorPlugin = require('code-inspector-plugin').codeInspectorPlugin;
} catch (e) {
  console.warn("code-inspector-plugin not found, continuing without it");
  codeInspectorPlugin = null;
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config, { dev, isServer }) => {
    // Only add the plugin if it was successfully loaded
    if (codeInspectorPlugin) {
      config.plugins.push(codeInspectorPlugin({ bundler: 'webpack' }));
    }
    return config;
  },
  productionBrowserSourceMaps: false,
  pageExtensions: ['ts', 'tsx', 'js', 'jsx', 'md', 'mdx'],
  experimental: {
  },
  eslint: {
    ignoreDuringBuilds: true,
    dirs: ['app', 'bin', 'config', 'context', 'hooks', 'i18n', 'models', 'service', 'test', 'types', 'utils'],
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  reactStrictMode: true,
  async redirects() {
    return [
      {
        source: '/',
        destination: '/apps',
        permanent: false,
      },
    ]
  },
  output: 'standalone',
}

module.exports = withMDX(nextConfig)