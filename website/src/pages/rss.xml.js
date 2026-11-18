import { getCollection } from 'astro:content';
import rss from '@astrojs/rss';
import { SITE_DESCRIPTION, SITE_TITLE } from '../consts';

export async function GET(context) {
  const posts = await getCollection('blog');
  // The site lives under a base path, so every link carries it.
  const base = import.meta.env.BASE_URL.replace(/\/$/, '');
  return rss({
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    site: new URL(`${base}/`, context.site).href,
    items: posts.map(post => ({
      ...post.data,
      link: `${base}/blog/${post.id}/`,
    })),
  });
}
