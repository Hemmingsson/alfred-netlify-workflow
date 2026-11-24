/// Netlify's framework ids as people write them; unknown frameworks are left out.
enum FrameworkName {
    static func name(for id: String?) -> String? {
        switch id {
        case "svelte-kit": "SvelteKit"
        case "svelte": "Svelte"
        case "vite": "Vite"
        case "next": "Next.js"
        case "astro": "Astro"
        case "gatsby": "Gatsby"
        case "hugo": "Hugo"
        case "eleventy": "Eleventy"
        case "nuxt": "Nuxt"
        case "remix": "Remix"
        default: nil
        }
    }
}
