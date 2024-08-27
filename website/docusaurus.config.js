// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'AG Mod X',
  tagline: 'An improved Mini AG alternative',
  favicon: 'img/favicon.ico',

  // Set the production url of your site here
  url: 'https://rtxa.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/agmodx/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'rtxa', // Usually your GitHub org/user name.
  projectName: 'agmodx', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/rtxa/agmodx/tree/main/website/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: 'dark',
      },
      // Replace with your project's social card
      image: 'img/agmodx-social-card.png',
      navbar: {
        title: '',
        logo: {
          alt: 'AG Mod X',
          src: 'img/agmodx-logo-web-light.png',
          srcDark: 'img/agmodx-logo-web-dark.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'tutorialSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            to: '/downloads',
            label: 'Downloads',
            position: 'left',
          },
          {
            to: '/faq',
            label: 'FAQ',
          },
          {
            href: 'https://github.com/rtxa/agmodx',
            className: 'header-github-link',
            'aria-label': 'GitHub repository',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting started',
                to: '/docs/category/getting-started',
              },
              {
                label: 'Features',
                to: '/docs/getting-started/features',
              },
              {
                label: 'Game modes',
                to: '/docs/category/game-modes',
              },
              {
                label: 'Commands reference',
                to: '/docs/guides/commands',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'Downloads',
                to: '/downloads',
              },
              {
                label: 'FAQ',
                to: '/faq',
              },
              {
                label: 'Changelog',
                href: 'https://github.com/rtxa/agmodx/blob/master/CHANGELOG.md',
              },
              {
                label: 'GitHub',
                href: 'https://github.com/rtxa/agmodx',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} AG Mod X and contributors. Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;
