// @ts-check

/** @type {import('@docusaurus/types').Config} */
const repoSlug = process.env.GITHUB_REPOSITORY || "";
const repoName = repoSlug.includes("/") ? repoSlug.split("/")[1] : "";
const owner = process.env.GITHUB_REPOSITORY_OWNER || "";
const isCI = process.env.CI === "true" || process.env.GITHUB_ACTIONS === "true";
const siteBaseUrl = isCI && repoName ? `/${repoName}/docs/` : "/";

const config = {
  title: "AudioCap Recorder Docs",
  url: owner ? `https://${owner}.github.io` : "http://localhost:3000",
  baseUrl: siteBaseUrl,
  favicon: "img/favicon.ico",
  organizationName: "audiocap",
  projectName: "recorder",
  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */ ({
        docs: {
          sidebarPath: require.resolve("./sidebars.js"),
          path: "../Docs",
          routeBasePath: "/",
          includeCurrentVersion: true,
        },
        theme: {
          customCss: require.resolve("./src/css/custom.css"),
        },
      }),
    ],
  ],
  staticDirectories: ["static"],
  themeConfig: {
    navbar: {
      title: "AudioCap Recorder",
      items: [
        {
          type: "html",
          position: "right",
          value: '<div id="version-switcher" style="min-width:160px"></div>',
        },
      ],
    },
  },
  scripts: [siteBaseUrl + "js/version-switcher.js"],
};

module.exports = config;
