import React from 'react';
// Import the original mapper
import MDXComponents from '@theme-original/MDXComponents';
import IconExternalLink from "@theme/Icon/ExternalLink";
import { Icon, InlineIcon } from '@iconify/react'; // Import the entire Iconify library.
import Badge from '@site/src/components/Badge';

export default {
  // Re-use the default mapping
  ...MDXComponents,
  Icon, // Make the iconify Icon component available in MDX as <icon />.
  InlineIcon,
  IconExternalLink,
  Badge,
};

