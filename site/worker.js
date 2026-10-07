// Optional static-site worker. Montage has no short-link or hosted-data service.
const REPOSITORY = "https://github.com/tombychowski/omarchy-montage";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/repo") return Response.redirect(REPOSITORY, 302);
    if (url.pathname === "/" || url.pathname === "/index.html") {
      return env.ASSETS ? env.ASSETS.fetch(request) : Response.redirect(REPOSITORY, 302);
    }
    return new Response("Not found. Montage documentation: " + REPOSITORY + "\n", {
      status: 404,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
