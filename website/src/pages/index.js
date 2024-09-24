import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './index.module.css';
import { Icon, InlineIcon } from '@iconify/react';
import IconExternalLink from "@theme/Icon/ExternalLink";

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx(styles.headerSection)}>
      <div className="container">
        <img src="img/agmodx-logo-web-dark.png" className={clsx(styles.agmodxLogo)} />
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className={clsx("button button--primary button--lg", styles.buttonWithMargin)}
            to="/downloads">
            <InlineIcon icon="lucide:download" height="1.5rem" style={{ verticalAlign: 'text-bottom' }} /> Download Now
          </Link>
          <Link
            className={clsx("button button--secondary button--lg", styles.buttonWithMargin)}
            to="/docs/category/getting-started">
            <InlineIcon icon="lucide:file-text" height="1.5rem" style={{ verticalAlign: 'text-bottom' }} /> Read the docs
          </Link>
        </div>
        Latest version: <b>2.6</b> — <Link style={{ color: '#5a98fe' }} to='/changelog'>What's new?</Link>
      </div>
    </header>
  );
}

function FeaturesSection() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}

function Feature({ title, description, emoji }) {
  return (
    <div className={clsx('col col--6')}>
      <div className="text--center">
        {emoji}
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

const FeatureList = [
  {
    emoji: (<Icon style={{ color: '#5a98fe' }} icon="emojione-monotone:gear" height="2rem" />),
    title: 'Bugfixes and Improvements',
    description: (
      <>
        The mod includes new commands and improvements to existing ones, with bug fixes and
        QoL changes in the gameplay through the use of Bugfixed HL in the core of the mod. More info <Link to='/docs/getting-started/features'>here</Link>.
      </>
    ),
  },
  {
    emoji: (<Icon style={{ color: '#eac534' }} icon="material-symbols:cable" height="2rem" />),
    title: 'Portability and Flexibility',
    description: (
      <>
        The mod itself is an AMX Mod X plugin, allowing easy integration with other plugins on your server.
        You can easily disable the mod in case it conflicts with other plugins.
      </>
    ),
  },
  {
    emoji: (<Icon style={{ color: '#e18682' }} icon="material-symbols:language" height="2rem" />),
    title: 'Multi-Language Support',
    description: (
      <>
        The mod supports translations of texts, menus and HUDs, with English and Spanish translations included out-of-the-box.
      </>
    ),
  },
  {
    emoji: (<Icon style={{ color: '#9a8cdd' }} icon="ph:code-fill" height="2rem" />),
    title: 'Open-Source',
    description: (
      <>
        The mod's source code is available, allowing you to add new features and
        make improvements with just basic programming knowledge.
      </>
    ),
  },
];

function CtfSection() {
  return (
    <header className={clsx(styles.ctfSection)}>
      <div className="container">
        <div className="row">
          <div className={clsx('col col--6 text--left')}>
            <Heading as="h1" className="hero__title">CTF is back!</Heading>
            <p>
              Capture The Flag wasn't available in the original Mini AG due to some limitations, but now it's back!
              Players can enjoy this classic game mode, where two teams compete to hold and capture
              the opposing team's flag while defending their own. More info <Link style={{ color: '#5a98fe' }} to='/docs/gamemodes/ctf'>here</Link>.
            </p>
          </div>
          <div className={clsx('col col--6')}>
            <img src="img/ctf-players1.png" className={clsx(styles.ctfImage)} />
          </div>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.tagline}`}
      description="AG Mod X is an improved Mini AG alternative built as an AMXX plugin. It contains many bug fixes, improvements, and as an open-source project, allows easy customization and feature additions.">
      <HomepageHeader />
      <FeaturesSection />
      <CtfSection />
    </Layout>
  );
}