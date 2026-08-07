// Resolve bun-style extensionless relative imports to .ts for node.
export async function resolve(specifier, context, next) {
  try {
    return await next(specifier, context);
  } catch (e) {
    if (
      (specifier.startsWith("./") || specifier.startsWith("../")) &&
      !/\.[a-zA-Z]+$/.test(specifier)
    ) {
      return next(specifier + ".ts", context);
    }
    throw e;
  }
}
