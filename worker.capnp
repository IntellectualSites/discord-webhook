    ��            �   %) 7           m)    U                A   Z   D    
        �,  B   �,   
        �/  r   �/           �/  b   �/   
        �h  J   �h           �h  J   �h     core:user:              %      �+  Z   �+     �+  �           a,             \,                                     �      � .wrangler/dist/index.js var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/env.ts
var BoundEnv = class {
  ignoredBranchPattern;
  ignoredBranches;
  ignoredUsers;
  ignoredPayloads;
  githubWebhookSecret;
  constructor(env) {
    if (typeof env.IGNORED_BRANCHES_REGEX !== "undefined") {
      this.ignoredBranchPattern = new RegExp(env.IGNORED_BRANCHES_REGEX);
    }
    this.ignoredBranches = env.IGNORED_BRANCHES?.split(",") || [];
    this.ignoredUsers = env.IGNORED_USERS?.split(",") || [];
    this.ignoredPayloads = env.IGNORED_PAYLOADS?.split(",") || [];
    this.githubWebhookSecret = env.GITHUB_WEBHOOK_SECRET;
  }
  /**
   * @param {String} branch
   * @return {boolean}
   */
  isIgnoredBranch(branch) {
    return this.ignoredBranchPattern && branch.match(this.ignoredBranchPattern) != null || this.ignoredBranches.includes(branch);
  }
  /**
   * @param {String} user
   * @return {boolean}
   */
  isIgnoredUser(user) {
    return this.ignoredUsers.includes(user);
  }
  /**
   * @param {String} payload
   * @return {boolean}
   */
  isIgnoredPayload(payload) {
    return this.ignoredPayloads.includes(payload);
  }
  async buildDebugPaste(embed) {
    embed = JSON.stringify({
      "files": [
        {
          "content": {
            "format": "text",
            "value": embed
          }
        }
      ]
    });
    embed = await (await fetch("https://api.pastes.dev/post", {
      headers: {
        "user-agent": "disgit",
        "content-type": "application/json"
      },
      method: "POST",
      body: embed
    })).text();
    embed = JSON.stringify({
      "content": embed
    });
    return embed;
  }
};
__name(BoundEnv, "BoundEnv");

// src/util.ts
function truncate(str, num) {
  if (str === null) {
    return null;
  }
  str = str.replace(/<!--(?:.|\n|\r)*?-->[\n|\r]*/g, "");
  if (str.length <= num) {
    return str;
  }
  return str.slice(0, num - 3) + "...";
}
__name(truncate, "truncate");
function shortCommit(hash) {
  return hash.substring(0, 7);
}
__name(shortCommit, "shortCommit");

// src/index.ts
var debug = false;
async function handleRequest(request, env) {
  const event = request.headers.get("X-GitHub-Event");
  const contentType = request.headers.get("content-type");
  if (event != null && contentType != null) {
    let json;
    if (contentType.includes("application/json")) {
      json = await request.json();
    } else if (contentType.includes("application/x-www-form-urlencoded")) {
      json = JSON.parse((await request.formData()).get("payload"));
    } else {
      return new Response(`Unknown content type ${contentType}`, { status: 400 });
    }
    let embed = buildEmbed(json, event, env);
    if (embed == null) {
      return new Response("Webhook NO-OP", { status: 200 });
    }
    if (debug) {
      embed = await env.buildDebugPaste(embed);
    }
    const url = new URL(request.url);
    let [hookId, hookToken] = (url.pathname + url.search).substring(1).split("/");
    if (typeof hookToken == "undefined") {
      return new Response("Missing Webhook Authorization", { status: 400 });
    }
    await fetch(`https://discord.com/api/webhooks/${hookId}/${hookToken}`, {
      headers: {
        "content-type": "application/json;charset=UTF=8"
      },
      method: "POST",
      body: embed
    });
    return new Response(`disgit successfully executed webhook ${hookId}`, { status: 200 });
  } else {
    return new Response("Bad Request", { status: 400 });
  }
}
__name(handleRequest, "handleRequest");
function buildEmbed(json, event, env) {
  const { action } = json;
  if (env.isIgnoredPayload(event)) {
    return null;
  }
  switch (event) {
    case "check_run": {
      if (action !== "completed") {
        break;
      }
      return buildCheck(json, env);
    }
    case "commit_comment": {
      if (action !== "created") {
        break;
      }
      return buildCommitComment(json, env);
    }
    case "create": {
      return buildCreateBranch(json, env);
    }
    case "delete": {
      return buildDeleteBranch(json, env);
    }
    case "discussion": {
      if (action !== "created") {
        break;
      }
      return buildDiscussion(json, env);
    }
    case "discussion_comment": {
      if (action !== "created") {
        break;
      }
      return buildDiscussionComment(json, env);
    }
    case "fork": {
      return buildFork(json);
    }
    case "issue_comment": {
      if (action !== "created") {
        break;
      }
      return buildIssueComment(json, env);
    }
    case "issues": {
      switch (action) {
        case "opened": {
          return buildIssue(json, env);
        }
        case "reopened": {
          return buildIssueReOpen(json);
        }
        case "closed": {
          return buildIssueClose(json);
        }
        default: {
          return null;
        }
      }
    }
    case "package": {
      switch (action) {
        case "published": {
          return buildPackagePublished(json);
        }
        case "updated": {
          return buildPackageUpdated(json);
        }
        default: {
          return null;
        }
      }
    }
    case "ping": {
      return buildPing(json);
    }
    case "pull_request": {
      switch (action) {
        case "opened": {
          return buildPull(json, env);
        }
        case "closed": {
          return buildPullClose(json);
        }
        case "reopened": {
          return buildPullReopen(json);
        }
        case "converted_to_draft": {
          return buildPullDraft(json);
        }
        case "ready_for_review": {
          return buildPullReadyReview(json);
        }
        default: {
          return null;
        }
      }
    }
    case "pull_request_review": {
      switch (action) {
        case "submitted":
        case "dismissed": {
          return buildPullReview(json);
        }
        default: {
          return null;
        }
      }
    }
    case "pull_request_review_comment": {
      if (action !== "created") {
        break;
      }
      return buildPullReviewComment(json);
    }
    case "push": {
      return buildPush(json, env);
    }
    case "release": {
      if (action === "released" || action === "prereleased") {
        return buildRelease(json);
      }
      break;
    }
    case "star": {
      if (action !== "created") {
        break;
      }
      return buildStar(json);
    }
    case "deployment": {
      if (action !== "created") {
        break;
      }
      return buildDeployment(json);
    }
    case "deployment_status": {
      return buildDeploymentStatus(json);
    }
    case "gollum": {
      return buildWiki(json);
    }
  }
  return null;
}
__name(buildEmbed, "buildEmbed");
function buildEmbedBody(title, url, sender, color, description, footer, fields) {
  return JSON.stringify({
    embeds: [
      {
        title: truncate(title, 255),
        url,
        description: description ? truncate(description, 1e3) : void 0,
        author: {
          name: truncate(sender.login, 255),
          url: sender.html_url,
          icon_url: sender.avatar_url
        },
        color,
        footer: footer ? {
          text: truncate(footer, 255)
        } : void 0,
        fields: fields ?? []
      }
    ]
  });
}
__name(buildEmbedBody, "buildEmbedBody");
function buildPing(json) {
  const { zen, hook, repository, sender, organization } = json;
  const isOrg = hook["type"] == "Organization";
  const name = isOrg ? organization["login"] : repository["full_name"];
  return buildEmbedBody(`[${name}] ${hook.type} hook ping received`, void 0, sender, 12118406, zen);
}
__name(buildPing, "buildPing");
function buildRelease(json) {
  const { release, repository, sender } = json;
  const { draft, name, tag_name, body, html_url, prerelease } = release;
  if (draft) {
    return null;
  }
  let effectiveName = name == null ? tag_name : name;
  return buildEmbedBody(
    `[${repository["full_name"]}] New ${prerelease ? "pre" : ""}release published: ${effectiveName}`,
    html_url,
    sender,
    14573028,
    body
  );
}
__name(buildRelease, "buildRelease");
function buildPush(json, env) {
  const { commits, forced, after, repository, ref, compare, sender } = json;
  let branch = ref.substring(11);
  if (env.isIgnoredBranch(branch)) {
    return null;
  }
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  if (forced) {
    return buildEmbedBody(
      `[${repository["full_name"]}] Branch ${branch} was force-pushed to \`${shortCommit(after)}\``,
      compare.replace("...", ".."),
      sender,
      16722234
    );
  }
  let amount = commits.length;
  if (amount === 0) {
    return null;
  }
  let description = "";
  let lastCommitUrl = "";
  for (let i = 0; i < commits.length; i++) {
    let commit = commits[i];
    let commitUrl = commit.url;
    let line = `[\`${shortCommit(commit.id)}\`](${commitUrl}) ${truncate(commit.message.split("\n")[0], 50)} - ${commit.author.username}
`;
    if (description.length + line.length >= 1500) {
      break;
    }
    lastCommitUrl = commitUrl;
    description += line;
  }
  const commitWord = amount === 1 ? "commit" : "commits";
  return buildEmbedBody(
    `[${repository.name}:${branch}] ${amount} new ${commitWord}`,
    amount === 1 ? lastCommitUrl : compare,
    sender,
    6120164,
    description
  );
}
__name(buildPush, "buildPush");
function buildPullReviewComment(json) {
  const { pull_request, comment, repository, sender } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Pull request review comment: #${pull_request.number} ${pull_request.title}`,
    comment["html_url"],
    sender,
    7829367,
    comment.body
  );
}
__name(buildPullReviewComment, "buildPullReviewComment");
function buildPullReview(json) {
  const { pull_request, review, repository, action, sender } = json;
  let state = "reviewed";
  let color = 7829367;
  switch (review.state) {
    case "approved": {
      state = "approved";
      color = 37378;
      break;
    }
    case "changes_requested": {
      state = "changes requested";
      color = 16722234;
      break;
    }
    default: {
      if (action === "dismissed") {
        state = "review dismissed";
      }
      break;
    }
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] Pull request ${state}: #${pull_request.number} ${pull_request.title}`,
    review["html_url"],
    sender,
    color,
    review.body
  );
}
__name(buildPullReview, "buildPullReview");
function buildPullReadyReview(json) {
  const { pull_request, repository, sender } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Pull request marked for review: #${pull_request.number} ${pull_request.title}`,
    pull_request["html_url"],
    sender,
    37378
  );
}
__name(buildPullReadyReview, "buildPullReadyReview");
function buildPullDraft(json) {
  const { pull_request, repository, sender } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Pull request marked as draft: #${pull_request.number} ${pull_request.title}`,
    pull_request["html_url"],
    sender,
    10987431
  );
}
__name(buildPullDraft, "buildPullDraft");
function buildPullReopen(json) {
  const { pull_request, repository, sender } = json;
  let draft = pull_request.draft;
  let color = draft ? 10987431 : 37378;
  let type = draft ? "Draft pull request" : "Pull request";
  return buildEmbedBody(
    `[${repository["full_name"]}] ${type} reopened: #${pull_request.number} ${pull_request.title}`,
    pull_request["html_url"],
    sender,
    color
  );
}
__name(buildPullReopen, "buildPullReopen");
function buildPullClose(json) {
  const { pull_request, repository, sender } = json;
  let merged = pull_request.merged;
  let color = merged ? 8866047 : 16722234;
  let status = merged ? "merged" : "closed";
  return buildEmbedBody(
    `[${repository["full_name"]}] Pull request ${status}: #${pull_request.number} ${pull_request.title}`,
    pull_request["html_url"],
    sender,
    color
  );
}
__name(buildPullClose, "buildPullClose");
function buildPull(json, env) {
  const { pull_request, repository, sender } = json;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  let draft = pull_request.draft;
  let color = draft ? 10987431 : 37378;
  let type = draft ? "Draft pull request" : "Pull request";
  return buildEmbedBody(
    `[${repository["full_name"]}] ${type} opened: #${pull_request.number} ${pull_request.title}`,
    pull_request["html_url"],
    sender,
    color
  );
}
__name(buildPull, "buildPull");
function buildIssueComment(json, env) {
  const { issue, comment, repository, sender } = json;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  let entity = "pull_request" in issue ? "pull request" : "issue";
  return buildEmbedBody(
    `[${repository["full_name"]}] New comment on ${entity}: #${issue.number} ${issue.title}`,
    comment["html_url"],
    sender,
    11373312,
    comment.body
  );
}
__name(buildIssueComment, "buildIssueComment");
function buildIssueClose(json) {
  const { issue, repository, sender } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Issue closed: #${issue.number} ${issue.title}`,
    issue["html_url"],
    sender,
    16730159
  );
}
__name(buildIssueClose, "buildIssueClose");
function buildIssueReOpen(json) {
  const { issue, repository, sender } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Issue reopened: #${issue.number} ${issue.title}`,
    issue["html_url"],
    sender,
    16743680
  );
}
__name(buildIssueReOpen, "buildIssueReOpen");
function buildIssue(json, env) {
  const { issue, repository, sender } = json;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] Issue opened: #${issue.number} ${issue.title}`,
    issue["html_url"],
    sender,
    16743680,
    issue.body
  );
}
__name(buildIssue, "buildIssue");
function buildPackagePublished(json) {
  const { sender, repository } = json;
  const pkg = "package" in json ? json.package : json["registry_package"];
  return buildEmbedBody(
    `[${repository["full_name"]}] Package Published: ${pkg.namespace}/${pkg.name}`,
    pkg["package_version"]["html_url"],
    sender,
    37378
  );
}
__name(buildPackagePublished, "buildPackagePublished");
function buildPackageUpdated(json) {
  const { sender, repository } = json;
  const pkg = "package" in json ? json.package : json["registry_package"];
  return buildEmbedBody(
    `[${repository["full_name"]}] Package Updated: ${pkg.namespace}/${pkg.name}`,
    pkg["package_version"]["html_url"],
    sender,
    37378
  );
}
__name(buildPackageUpdated, "buildPackageUpdated");
function buildFork(json) {
  const { sender, repository, forkee } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] Fork Created: ${forkee["full_name"]}`,
    forkee["html_url"],
    sender,
    16562432
  );
}
__name(buildFork, "buildFork");
function buildDiscussionComment(json, env) {
  const { discussion, comment, repository, sender } = json;
  const { category } = discussion;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] New comment on discussion: #${discussion.number} ${discussion.title}`,
    comment["html_url"],
    sender,
    35446,
    comment.body,
    `Discussion Category: ${category.name}`
  );
}
__name(buildDiscussionComment, "buildDiscussionComment");
function buildDiscussion(json, env) {
  const { discussion, repository, sender } = json;
  const { category } = discussion;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] New discussion: #${discussion.number} ${discussion.title}`,
    discussion["html_url"],
    sender,
    9737471,
    discussion.body,
    `Discussion Category: ${category.name}`
  );
}
__name(buildDiscussion, "buildDiscussion");
function buildDeleteBranch(json, env) {
  const { ref, ref_type, repository, sender } = json;
  if (ref_type == "branch" && env.isIgnoredBranch(ref)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] ${ref_type} deleted: ${ref}`,
    void 0,
    sender,
    1
  );
}
__name(buildDeleteBranch, "buildDeleteBranch");
function buildCreateBranch(json, env) {
  const { ref, ref_type, repository, sender } = json;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  if (ref_type == "branch" && env.isIgnoredBranch(ref)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] New ${ref_type} created: ${ref}`,
    void 0,
    sender,
    1
  );
}
__name(buildCreateBranch, "buildCreateBranch");
function buildCommitComment(json, env) {
  const { sender, comment, repository } = json;
  if (env.isIgnoredUser(sender.login)) {
    return null;
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] New comment on commit \`${shortCommit(comment["commit_id"])}\``,
    comment["html_url"],
    sender,
    1,
    comment.body
  );
}
__name(buildCommitComment, "buildCommitComment");
function buildCheck(json, env) {
  const { check_run, repository, sender } = json;
  const { conclusion, output, html_url, check_suite } = check_run;
  if (repository == null || check_suite["head_branch"] == null) {
    return null;
  }
  let target = check_suite["head_branch"];
  if (env.isIgnoredBranch(target)) {
    return null;
  }
  if (check_suite["pull_requests"].length > 0) {
    let pull = check_suite["pull_requests"][0];
    if (pull.url.startsWith(`https://api.github.com/repos/${repository["full_name"]}`)) {
      target = `PR #${pull.number}`;
    }
  }
  let color = 11184810;
  let status = "failed";
  if (conclusion === "success") {
    color = 45866;
    status = "succeeded";
  } else if (conclusion === "failure" || conclusion === "cancelled") {
    color = 16726843;
    status = conclusion === "failure" ? "failed" : "cancelled";
  } else if (conclusion === "timed_out" || conclusion === "action_required" || conclusion === "stale") {
    color = 14984995;
    status = conclusion === "timed_out" ? "timed out" : conclusion === "action_required" ? "requires action" : "became stale";
  } else if (conclusion === "neutral") {
    status = "didn't run";
  } else if (conclusion === "skipped") {
    status = "was skipped";
  }
  let fields = [
    {
      name: "Action Name",
      value: check_run.name,
      inline: true
    }
  ];
  if (output.title != null) {
    fields.push({
      name: "Output Title",
      value: truncate(output.title, 1e3),
      inline: true
    });
  }
  if (output.summary != null) {
    fields.push({
      name: "Output Summary",
      value: truncate(output.summary, 1e3),
      inline: false
    });
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] Actions check ${status} on ${target}`,
    html_url,
    sender,
    color,
    void 0,
    void 0,
    fields
  );
}
__name(buildCheck, "buildCheck");
function buildStar(json) {
  const { sender, repository } = json;
  return buildEmbedBody(
    `[${repository["full_name"]}] New star added`,
    repository["html_url"],
    sender,
    16562432
  );
}
__name(buildStar, "buildStar");
function buildDeployment(json) {
  const { deployment, repository, sender } = json;
  const { description, payload } = deployment;
  return buildEmbedBody(
    `[${repository["full_name"]}] Deployment started for ${description}`,
    payload["web_url"] === null ? "" : payload["web_url"],
    sender,
    11158713
  );
}
__name(buildDeployment, "buildDeployment");
function buildDeploymentStatus(json) {
  const { deployment, deployment_status, repository, sender } = json;
  const { description, payload } = deployment;
  const { state } = deployment_status;
  let color = 16726843;
  let term = "succeeded";
  switch (state) {
    case "success": {
      color = 45866;
      break;
    }
    case "failure": {
      term = "failed";
      break;
    }
    case "error": {
      term = "errored";
      break;
    }
    default: {
      return null;
    }
  }
  return buildEmbedBody(
    `[${repository["full_name"]}] Deployment for ${description} ${term}`,
    payload["web_url"] === null ? "" : payload["web_url"],
    sender,
    color
  );
}
__name(buildDeploymentStatus, "buildDeploymentStatus");
function buildWiki(json) {
  const { pages, sender, repository } = json;
  let created = 0;
  let edited = 0;
  let titles = [];
  for (let i = 0; i < pages.length; i++) {
    const { action } = pages[i];
    if (action === "created") {
      created++;
    } else if (action === "edited") {
      edited++;
    }
    let title = `[${pages[i].title}](${pages[i]["html_url"]})`;
    titles.push(`${action.charAt(0).toUpperCase() + action.slice(1)}: ${title}`);
  }
  if (created === 0 && edited === 0) {
    return null;
  }
  let message;
  let color;
  if (created === 1 && edited === 0) {
    message = "A page was created";
    color = 45866;
  } else if (created === 0 && edited === 1) {
    message = "A page was edited";
    color = 16562432;
  } else {
    if (created > 0 && edited > 0) {
      message = `${created} page${created > 1 ? "s" : ""} were created and ${edited} ${edited > 1 ? "were" : "was"} edited`;
    } else {
      message = `${Math.max(created, edited)} pages were ${created > 0 ? "created" : "edited"}`;
    }
    color = 6120164;
  }
  message = `[${repository["full_name"]}] ${message}`;
  return buildEmbedBody(
    message,
    repository["html_url"],
    sender,
    color,
    titles.join("\n")
  );
}
__name(buildWiki, "buildWiki");
function handleError(error) {
  console.error("Uncaught error:", error);
  const { stack } = error;
  return new Response(stack || error, {
    status: 500,
    headers: {
      "Content-Type": "text/plain;charset=UTF-8"
    }
  });
}
__name(handleError, "handleError");
var src_default = {
  async fetch(request, env, ctx) {
    const bound = new BoundEnv(env);
    return handleRequest(request, bound).catch(handleError);
  }
};
export {
  src_default as default
};
//# sourceMappingURL=index.js.map

//# sourceURL=file:///C:/Users/joshr/WebstormProjects/disgit/.wrangler/dist/index.js
 2022-11-10                  i   �   q   �                                          e   �   m   �                                          a   r   e   r                                          U   �   ]   �                                   IGNORED_BRANCH_REGEX    IGNORED_BRANCH_REGEX    IGNORED_BRANCHES        IGNORED_BRANCHES        IGNORED_USERS   IGNORED_USERS   IGNORED_PAYLOADS        IGNORED_PAYLOADS                 B           cache:0 cache:0         E      !   Z   %      �  w                                                   2023-07-24         r   	   j   nodejs_compat   experimental                    �      *#  cache-entry.worker.js   // src/workers/cache/cache-entry.worker.ts
import { SharedBindings } from "miniflare:shared";

// src/workers/cache/constants.ts
var CacheHeaders = {
  NAMESPACE: "cf-cache-namespace",
  STATUS: "cf-cache-status"
}, CacheBindings = {
  MAYBE_JSON_CACHE_WARN_USAGE: "MINIFLARE_CACHE_WARN_USAGE"
};

// src/workers/cache/cache-entry.worker.ts
var cache_entry_worker_default = {
  async fetch(request, env) {
    let namespace = request.headers.get(CacheHeaders.NAMESPACE), name = namespace === null ? "default" : `named:${namespace}`, objectNamespace = env[SharedBindings.DURABLE_OBJECT_NAMESPACE_OBJECT], id = objectNamespace.idFromName(name), stub = objectNamespace.get(id), cf = {
      ...request.cf,
      miniflare: {
        name,
        cacheWarnUsage: env[CacheBindings.MAYBE_JSON_CACHE_WARN_USAGE]
      }
    };
    return await stub.fetch(request, { cf });
  }
};
export {
  cache_entry_worker_default as default
};
//# sourceMappingURL=cache-entry.worker.js.map
//# sourceURL=file:///C:/Users/joshr/AppData/Local/Temp/bunx-3240478352-selflare@latest/node_modules/selflare/dist/workers/cache/cache-entry.worker.js                1   �   8                                             9   �   E   2                                   MINIFLARE_OBJECT           b      b   cache:cache     CacheObject     MINIFLARE_CACHE_WARN_USAGE      false   cache:storage             B   ./cache cache:cache            E      !   Z   %      Q8  w           8                     58  r           2023-07-24         r   	   j   nodejs_compat   experimental                    �   	   B} cache.worker.js var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf, __hasOwnProp = Object.prototype.hasOwnProperty;
var __commonJS = (cb, mod) => function() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from == "object" || typeof from == "function")
    for (let key of __getOwnPropNames(from))
      !__hasOwnProp.call(to, key) && key !== except && __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: !0 }) : target,
  mod
));
var __decorateClass = (decorators, target, key, kind) => {
  for (var result = kind > 1 ? void 0 : kind ? __getOwnPropDesc(target, key) : target, i = decorators.length - 1, decorator; i >= 0; i--)
    (decorator = decorators[i]) && (result = (kind ? decorator(target, key, result) : decorator(result)) || result);
  return kind && result && __defProp(target, key, result), result;
};

// ../../node_modules/.pnpm/http-cache-semantics@4.1.0/node_modules/http-cache-semantics/index.js
var require_http_cache_semantics = __commonJS({
  "../../node_modules/.pnpm/http-cache-semantics@4.1.0/node_modules/http-cache-semantics/index.js"(exports, module) {
    "use strict";
    var statusCodeCacheableByDefault = /* @__PURE__ */ new Set([
      200,
      203,
      204,
      206,
      300,
      301,
      404,
      405,
      410,
      414,
      501
    ]), understoodStatuses = /* @__PURE__ */ new Set([
      200,
      203,
      204,
      300,
      301,
      302,
      303,
      307,
      308,
      404,
      405,
      410,
      414,
      501
    ]), errorStatusCodes = /* @__PURE__ */ new Set([
      500,
      502,
      503,
      504
    ]), hopByHopHeaders = {
      date: !0,
      // included, because we add Age update Date
      connection: !0,
      "keep-alive": !0,
      "proxy-authenticate": !0,
      "proxy-authorization": !0,
      te: !0,
      trailer: !0,
      "transfer-encoding": !0,
      upgrade: !0
    }, excludedFromRevalidationUpdate = {
      // Since the old body is reused, it doesn't make sense to change properties of the body
      "content-length": !0,
      "content-encoding": !0,
      "transfer-encoding": !0,
      "content-range": !0
    };
    function toNumberOrZero(s) {
      let n = parseInt(s, 10);
      return isFinite(n) ? n : 0;
    }
    function isErrorResponse(response) {
      return response ? errorStatusCodes.has(response.status) : !0;
    }
    function parseCacheControl(header) {
      let cc = {};
      if (!header)
        return cc;
      let parts = header.trim().split(/\s*,\s*/);
      for (let part of parts) {
        let [k, v] = part.split(/\s*=\s*/, 2);
        cc[k] = v === void 0 ? !0 : v.replace(/^"|"$/g, "");
      }
      return cc;
    }
    function formatCacheControl(cc) {
      let parts = [];
      for (let k in cc) {
        let v = cc[k];
        parts.push(v === !0 ? k : k + "=" + v);
      }
      if (parts.length)
        return parts.join(", ");
    }
    module.exports = class {
      constructor(req, res, {
        shared,
        cacheHeuristic,
        immutableMinTimeToLive,
        ignoreCargoCult,
        _fromObject
      } = {}) {
        if (_fromObject) {
          this._fromObject(_fromObject);
          return;
        }
        if (!res || !res.headers)
          throw Error("Response headers missing");
        this._assertRequestHasHeaders(req), this._responseTime = this.now(), this._isShared = shared !== !1, this._cacheHeuristic = cacheHeuristic !== void 0 ? cacheHeuristic : 0.1, this._immutableMinTtl = immutableMinTimeToLive !== void 0 ? immutableMinTimeToLive : 24 * 3600 * 1e3, this._status = "status" in res ? res.status : 200, this._resHeaders = res.headers, this._rescc = parseCacheControl(res.headers["cache-control"]), this._method = "method" in req ? req.method : "GET", this._url = req.url, this._host = req.headers.host, this._noAuthorization = !req.headers.authorization, this._reqHeaders = res.headers.vary ? req.headers : null, this._reqcc = parseCacheControl(req.headers["cache-control"]), ignoreCargoCult && "pre-check" in this._rescc && "post-check" in this._rescc && (delete this._rescc["pre-check"], delete this._rescc["post-check"], delete this._rescc["no-cache"], delete this._rescc["no-store"], delete this._rescc["must-revalidate"], this._resHeaders = Object.assign({}, this._resHeaders, {
          "cache-control": formatCacheControl(this._rescc)
        }), delete this._resHeaders.expires, delete this._resHeaders.pragma), res.headers["cache-control"] == null && /no-cache/.test(res.headers.pragma) && (this._rescc["no-cache"] = !0);
      }
      now() {
        return Date.now();
      }
      storable() {
        return !!(!this._reqcc["no-store"] && // A cache MUST NOT store a response to any request, unless:
        // The request method is understood by the cache and defined as being cacheable, and
        (this._method === "GET" || this._method === "HEAD" || this._method === "POST" && this._hasExplicitExpiration()) && // the response status code is understood by the cache, and
        understoodStatuses.has(this._status) && // the "no-store" cache directive does not appear in request or response header fields, and
        !this._rescc["no-store"] && // the "private" response directive does not appear in the response, if the cache is shared, and
        (!this._isShared || !this._rescc.private) && // the Authorization header field does not appear in the request, if the cache is shared,
        (!this._isShared || this._noAuthorization || this._allowsStoringAuthenticated()) && // the response either:
        // contains an Expires header field, or
        (this._resHeaders.expires || // contains a max-age response directive, or
        // contains a s-maxage response directive and the cache is shared, or
        // contains a public response directive.
        this._rescc["max-age"] || this._isShared && this._rescc["s-maxage"] || this._rescc.public || // has a status code that is defined as cacheable by default
        statusCodeCacheableByDefault.has(this._status)));
      }
      _hasExplicitExpiration() {
        return this._isShared && this._rescc["s-maxage"] || this._rescc["max-age"] || this._resHeaders.expires;
      }
      _assertRequestHasHeaders(req) {
        if (!req || !req.headers)
          throw Error("Request headers missing");
      }
      satisfiesWithoutRevalidation(req) {
        this._assertRequestHasHeaders(req);
        let requestCC = parseCacheControl(req.headers["cache-control"]);
        return requestCC["no-cache"] || /no-cache/.test(req.headers.pragma) || requestCC["max-age"] && this.age() > requestCC["max-age"] || requestCC["min-fresh"] && this.timeToLive() < 1e3 * requestCC["min-fresh"] || this.stale() && !(requestCC["max-stale"] && !this._rescc["must-revalidate"] && (requestCC["max-stale"] === !0 || requestCC["max-stale"] > this.age() - this.maxAge())) ? !1 : this._requestMatches(req, !1);
      }
      _requestMatches(req, allowHeadMethod) {
        return (!this._url || this._url === req.url) && this._host === req.headers.host && // the request method associated with the stored response allows it to be used for the presented request, and
        (!req.method || this._method === req.method || allowHeadMethod && req.method === "HEAD") && // selecting header fields nominated by the stored response (if any) match those presented, and
        this._varyMatches(req);
      }
      _allowsStoringAuthenticated() {
        return this._rescc["must-revalidate"] || this._rescc.public || this._rescc["s-maxage"];
      }
      _varyMatches(req) {
        if (!this._resHeaders.vary)
          return !0;
        if (this._resHeaders.vary === "*")
          return !1;
        let fields = this._resHeaders.vary.trim().toLowerCase().split(/\s*,\s*/);
        for (let name of fields)
          if (req.headers[name] !== this._reqHeaders[name])
            return !1;
        return !0;
      }
      _copyWithoutHopByHopHeaders(inHeaders) {
        let headers = {};
        for (let name in inHeaders)
          hopByHopHeaders[name] || (headers[name] = inHeaders[name]);
        if (inHeaders.connection) {
          let tokens = inHeaders.connection.trim().split(/\s*,\s*/);
          for (let name of tokens)
            delete headers[name];
        }
        if (headers.warning) {
          let warnings = headers.warning.split(/,/).filter((warning) => !/^\s*1[0-9][0-9]/.test(warning));
          warnings.length ? headers.warning = warnings.join(",").trim() : delete headers.warning;
        }
        return headers;
      }
      responseHeaders() {
        let headers = this._copyWithoutHopByHopHeaders(this._resHeaders), age = this.age();
        return age > 3600 * 24 && !this._hasExplicitExpiration() && this.maxAge() > 3600 * 24 && (headers.warning = (headers.warning ? `${headers.warning}, ` : "") + '113 - "rfc7234 5.5.4"'), headers.age = `${Math.round(age)}`, headers.date = new Date(this.now()).toUTCString(), headers;
      }
      /**
       * Value of the Date response header or current time if Date was invalid
       * @return timestamp
       */
      date() {
        let serverDate = Date.parse(this._resHeaders.date);
        return isFinite(serverDate) ? serverDate : this._responseTime;
      }
      /**
       * Value of the Age header, in seconds, updated for the current time.
       * May be fractional.
       *
       * @return Number
       */
      age() {
        let age = this._ageValue(), residentTime = (this.now() - this._responseTime) / 1e3;
        return age + residentTime;
      }
      _ageValue() {
        return toNumberOrZero(this._resHeaders.age);
      }
      /**
       * Value of applicable max-age (or heuristic equivalent) in seconds. This counts since response's `Date`.
       *
       * For an up-to-date value, see `timeToLive()`.
       *
       * @return Number
       */
      maxAge() {
        if (!this.storable() || this._rescc["no-cache"] || this._isShared && this._resHeaders["set-cookie"] && !this._rescc.public && !this._rescc.immutable || this._resHeaders.vary === "*")
          return 0;
        if (this._isShared) {
          if (this._rescc["proxy-revalidate"])
            return 0;
          if (this._rescc["s-maxage"])
            return toNumberOrZero(this._rescc["s-maxage"]);
        }
        if (this._rescc["max-age"])
          return toNumberOrZero(this._rescc["max-age"]);
        let defaultMinTtl = this._rescc.immutable ? this._immutableMinTtl : 0, serverDate = this.date();
        if (this._resHeaders.expires) {
          let expires = Date.parse(this._resHeaders.expires);
          return Number.isNaN(expires) || expires < serverDate ? 0 : Math.max(defaultMinTtl, (expires - serverDate) / 1e3);
        }
        if (this._resHeaders["last-modified"]) {
          let lastModified = Date.parse(this._resHeaders["last-modified"]);
          if (isFinite(lastModified) && serverDate > lastModified)
            return Math.max(
              defaultMinTtl,
              (serverDate - lastModified) / 1e3 * this._cacheHeuristic
            );
        }
        return defaultMinTtl;
      }
      timeToLive() {
        let age = this.maxAge() - this.age(), staleIfErrorAge = age + toNumberOrZero(this._rescc["stale-if-error"]), staleWhileRevalidateAge = age + toNumberOrZero(this._rescc["stale-while-revalidate"]);
        return Math.max(0, age, staleIfErrorAge, staleWhileRevalidateAge) * 1e3;
      }
      stale() {
        return this.maxAge() <= this.age();
      }
      _useStaleIfError() {
        return this.maxAge() + toNumberOrZero(this._rescc["stale-if-error"]) > this.age();
      }
      useStaleWhileRevalidate() {
        return this.maxAge() + toNumberOrZero(this._rescc["stale-while-revalidate"]) > this.age();
      }
      static fromObject(obj) {
        return new this(void 0, void 0, { _fromObject: obj });
      }
      _fromObject(obj) {
        if (this._responseTime)
          throw Error("Reinitialized");
        if (!obj || obj.v !== 1)
          throw Error("Invalid serialization");
        this._responseTime = obj.t, this._isShared = obj.sh, this._cacheHeuristic = obj.ch, this._immutableMinTtl = obj.imm !== void 0 ? obj.imm : 24 * 3600 * 1e3, this._status = obj.st, this._resHeaders = obj.resh, this._rescc = obj.rescc, this._method = obj.m, this._url = obj.u, this._host = obj.h, this._noAuthorization = obj.a, this._reqHeaders = obj.reqh, this._reqcc = obj.reqcc;
      }
      toObject() {
        return {
          v: 1,
          t: this._responseTime,
          sh: this._isShared,
          ch: this._cacheHeuristic,
          imm: this._immutableMinTtl,
          st: this._status,
          resh: this._resHeaders,
          rescc: this._rescc,
          m: this._method,
          u: this._url,
          h: this._host,
          a: this._noAuthorization,
          reqh: this._reqHeaders,
          reqcc: this._reqcc
        };
      }
      /**
       * Headers for sending to the origin server to revalidate stale response.
       * Allows server to return 304 to allow reuse of the previous response.
       *
       * Hop by hop headers are always stripped.
       * Revalidation headers may be added or removed, depending on request.
       */
      revalidationHeaders(incomingReq) {
        this._assertRequestHasHeaders(incomingReq);
        let headers = this._copyWithoutHopByHopHeaders(incomingReq.headers);
        if (delete headers["if-range"], !this._requestMatches(incomingReq, !0) || !this.storable())
          return delete headers["if-none-match"], delete headers["if-modified-since"], headers;
        if (this._resHeaders.etag && (headers["if-none-match"] = headers["if-none-match"] ? `${headers["if-none-match"]}, ${this._resHeaders.etag}` : this._resHeaders.etag), headers["accept-ranges"] || headers["if-match"] || headers["if-unmodified-since"] || this._method && this._method != "GET") {
          if (delete headers["if-modified-since"], headers["if-none-match"]) {
            let etags = headers["if-none-match"].split(/,/).filter((etag) => !/^\s*W\//.test(etag));
            etags.length ? headers["if-none-match"] = etags.join(",").trim() : delete headers["if-none-match"];
          }
        } else
          this._resHeaders["last-modified"] && !headers["if-modified-since"] && (headers["if-modified-since"] = this._resHeaders["last-modified"]);
        return headers;
      }
      /**
       * Creates new CachePolicy with information combined from the previews response,
       * and the new revalidation response.
       *
       * Returns {policy, modified} where modified is a boolean indicating
       * whether the response body has been modified, and old cached body can't be used.
       *
       * @return {Object} {policy: CachePolicy, modified: Boolean}
       */
      revalidatedPolicy(request, response) {
        if (this._assertRequestHasHeaders(request), this._useStaleIfError() && isErrorResponse(response))
          return {
            modified: !1,
            matches: !1,
            policy: this
          };
        if (!response || !response.headers)
          throw Error("Response headers missing");
        let matches = !1;
        if (response.status !== void 0 && response.status != 304 ? matches = !1 : response.headers.etag && !/^\s*W\//.test(response.headers.etag) ? matches = this._resHeaders.etag && this._resHeaders.etag.replace(/^\s*W\//, "") === response.headers.etag : this._resHeaders.etag && response.headers.etag ? matches = this._resHeaders.etag.replace(/^\s*W\//, "") === response.headers.etag.replace(/^\s*W\//, "") : this._resHeaders["last-modified"] ? matches = this._resHeaders["last-modified"] === response.headers["last-modified"] : !this._resHeaders.etag && !this._resHeaders["last-modified"] && !response.headers.etag && !response.headers["last-modified"] && (matches = !0), !matches)
          return {
            policy: new this.constructor(request, response),
            // Client receiving 304 without body, even if it's invalid/mismatched has no option
            // but to reuse a cached body. We don't have a good way to tell clients to do
            // error recovery in such case.
            modified: response.status != 304,
            matches: !1
          };
        let headers = {};
        for (let k in this._resHeaders)
          headers[k] = k in response.headers && !excludedFromRevalidationUpdate[k] ? response.headers[k] : this._resHeaders[k];
        let newResponse = Object.assign({}, response, {
          status: this._status,
          method: this._method,
          headers
        });
        return {
          policy: new this.constructor(request, newResponse, {
            shared: this._isShared,
            cacheHeuristic: this._cacheHeuristic,
            immutableMinTimeToLive: this._immutableMinTtl
          }),
          modified: !1,
          matches: !0
        };
      }
    };
  }
});

// src/workers/cache/cache.worker.ts
var import_http_cache_semantics = __toESM(require_http_cache_semantics());
import assert from "node:assert";
import { Buffer as Buffer2 } from "node:buffer";
import {
  DeferredPromise,
  GET,
  KeyValueStorage,
  LogLevel,
  MiniflareDurableObject,
  PURGE,
  PUT,
  parseRanges
} from "miniflare:shared";

// src/workers/kv/constants.ts
import { testRegExps } from "miniflare:shared";
var KVLimits = {
  MIN_CACHE_TTL: 60,
  MAX_LIST_KEYS: 1e3,
  MAX_KEY_SIZE: 512,
  MAX_VALUE_SIZE: 25 * 1024 * 1024,
  MAX_VALUE_SIZE_TEST: 1024,
  MAX_METADATA_SIZE: 1024
};
var SITES_NO_CACHE_PREFIX = "$__MINIFLARE_SITES__$/";
function isSitesRequest(request) {
  return new URL(request.url).pathname.startsWith(`/${SITES_NO_CACHE_PREFIX}`);
}

// src/workers/cache/errors.worker.ts
import { HttpError } from "miniflare:shared";

// src/workers/cache/constants.ts
var CacheHeaders = {
  NAMESPACE: "cf-cache-namespace",
  STATUS: "cf-cache-status"
};

// src/workers/cache/errors.worker.ts
var CacheError = class extends HttpError {
  constructor(code, message, headers = []) {
    super(code, message);
    this.headers = headers;
  }
  toResponse() {
    return new Response(null, {
      status: this.code,
      headers: this.headers
    });
  }
  context(info) {
    return this.message += ` (${info})`, this;
  }
}, StorageFailure = class extends CacheError {
  constructor() {
    super(413, "Cache storage failed");
  }
}, PurgeFailure = class extends CacheError {
  constructor() {
    super(404, "Couldn't find asset to purge");
  }
}, CacheMiss = class extends CacheError {
  constructor() {
    super(
      // workerd ignores this, but it's the correct status code
      504,
      "Asset not found in cache",
      [[CacheHeaders.STATUS, "MISS"]]
    );
  }
}, RangeNotSatisfiable = class extends CacheError {
  constructor(size) {
    super(416, "Range not satisfiable", [
      ["Content-Range", `bytes */${size}`],
      [CacheHeaders.STATUS, "HIT"]
    ]);
  }
};

// src/workers/cache/cache.worker.ts
function getCacheKey(req) {
  return req.cf?.cacheKey ? String(req.cf?.cacheKey) : req.url;
}
function getExpiration(timers, req, res) {
  let reqHeaders = normaliseHeaders(req.headers);
  delete reqHeaders["cache-control"];
  let resHeaders = normaliseHeaders(res.headers);
  resHeaders["cache-control"]?.toLowerCase().includes("private=set-cookie") && (resHeaders["cache-control"] = resHeaders["cache-control"]?.toLowerCase().replace(/private=set-cookie;?/i, ""), delete resHeaders["set-cookie"]);
  let cacheReq = {
    url: req.url,
    // If a request gets to the Cache service, it's method will be GET. See README.md for details
    method: "GET",
    headers: reqHeaders
  }, cacheRes = {
    status: res.status,
    headers: resHeaders
  }, originalNow = import_http_cache_semantics.default.prototype.now;
  import_http_cache_semantics.default.prototype.now = timers.now;
  try {
    let policy = new import_http_cache_semantics.default(cacheReq, cacheRes, { shared: !0 });
    return {
      // Check if the request & response is cacheable
      storable: policy.storable() && !("set-cookie" in resHeaders),
      expiration: policy.timeToLive(),
      // Cache Policy Headers is typed as [header: string]: string | string[] | undefined
      // It's safe to ignore the undefined here, which is what casting to HeadersInit does
      headers: policy.responseHeaders()
    };
  } finally {
    import_http_cache_semantics.default.prototype.now = originalNow;
  }
}
function normaliseHeaders(headers) {
  let result = {};
  for (let [key, value] of headers)
    result[key.toLowerCase()] = value;
  return result;
}
var etagRegexp = /^(W\/)?"(.+)"$/;
function parseETag(value) {
  return etagRegexp.exec(value.trim())?.[2] ?? void 0;
}
var utcDateRegexp = /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d\d\d\d \d\d:\d\d:\d\d GMT$/;
function parseUTCDate(value) {
  return utcDateRegexp.test(value) ? Date.parse(value) : NaN;
}
function getMatchResponse(reqHeaders, res) {
  let reqIfNoneMatchHeader = reqHeaders.get("If-None-Match"), resETagHeader = res.headers.get("ETag");
  if (reqIfNoneMatchHeader !== null && resETagHeader !== null) {
    let resETag = parseETag(resETagHeader);
    if (resETag !== void 0) {
      if (reqIfNoneMatchHeader.trim() === "*")
        return new Response(null, { status: 304, headers: res.headers });
      for (let reqIfNoneMatch of reqIfNoneMatchHeader.split(","))
        if (resETag === parseETag(reqIfNoneMatch))
          return new Response(null, { status: 304, headers: res.headers });
    }
  }
  let reqIfModifiedSinceHeader = reqHeaders.get("If-Modified-Since"), resLastModifiedHeader = res.headers.get("Last-Modified");
  if (reqIfModifiedSinceHeader !== null && resLastModifiedHeader !== null) {
    let reqIfModifiedSince = parseUTCDate(reqIfModifiedSinceHeader);
    if (parseUTCDate(resLastModifiedHeader) <= reqIfModifiedSince)
      return new Response(null, { status: 304, headers: res.headers });
  }
  if (res.ranges.length > 0)
    if (res.status = 206, res.ranges.length > 1)
      assert(!(res.body instanceof ReadableStream)), res.headers.set("Content-Type", res.body.multipartContentType);
    else {
      let { start, end } = res.ranges[0];
      res.headers.set(
        "Content-Range",
        `bytes ${start}-${end}/${res.totalSize}`
      ), res.headers.set("Content-Length", `${end - start + 1}`);
    }
  return res.body instanceof ReadableStream || (res.body = res.body.body), new Response(res.body, { status: res.status, headers: res.headers });
}
var CR = "\r".charCodeAt(0), LF = `
`.charCodeAt(0), STATUS_REGEXP = /^HTTP\/\d(?:\.\d)? (?<rawStatusCode>\d+) (?<statusText>.*)$/;
async function parseHttpResponse(stream) {
  let buffer = Buffer2.alloc(0), blankLineIndex = -1;
  for await (let chunk of stream.values({ preventCancel: !0 }))
    if (buffer = Buffer2.concat([buffer, chunk]), blankLineIndex = buffer.findIndex(
      (_value, index) => buffer[index] === CR && buffer[index + 1] === LF && buffer[index + 2] === CR && buffer[index + 3] === LF
    ), blankLineIndex !== -1)
      break;
  assert(blankLineIndex !== -1, "Expected to find blank line in HTTP message");
  let rawStatusHeaders = buffer.subarray(0, blankLineIndex).toString(), [rawStatus, ...rawHeaders] = rawStatusHeaders.split(`\r
`), statusMatch = rawStatus.match(STATUS_REGEXP);
  assert(
    statusMatch?.groups != null,
    `Expected first line ${JSON.stringify(rawStatus)} to be HTTP status line`
  );
  let { rawStatusCode, statusText } = statusMatch.groups, statusCode = parseInt(rawStatusCode), headers = rawHeaders.map((rawHeader) => {
    let index = rawHeader.indexOf(":");
    return [
      rawHeader.substring(0, index),
      rawHeader.substring(index + 1).trim()
    ];
  }), prefix = buffer.subarray(
    blankLineIndex + 4
    /* "\r\n\r\n" */
  ), { readable, writable } = new IdentityTransformStream(), writer = writable.getWriter();
  return writer.write(prefix).then(() => (writer.releaseLock(), stream.pipeTo(writable))).catch((e) => console.error("Error writing HTTP body:", e)), new Response(readable, { status: statusCode, statusText, headers });
}
var SizingStream = class extends TransformStream {
  size;
  constructor() {
    let sizePromise = new DeferredPromise(), size = 0;
    super({
      transform(chunk, controller) {
        size += chunk.byteLength, controller.enqueue(chunk);
      },
      flush() {
        sizePromise.resolve(size);
      }
    }), this.size = sizePromise;
  }
}, CacheObject = class extends MiniflareDurableObject {
  #warnedUsage = !1;
  async #maybeWarnUsage(request) {
    !this.#warnedUsage && request.cf?.miniflare?.cacheWarnUsage === !0 && (this.#warnedUsage = !0, await this.logWithLevel(
      LogLevel.WARN,
      "Cache operations will have no impact if you deploy to a workers.dev subdomain!"
    ));
  }
  #storage;
  get storage() {
    return this.#storage ??= new KeyValueStorage(this);
  }
  match = async (req) => {
    await this.#maybeWarnUsage(req);
    let cacheKey = getCacheKey(req);
    if (isSitesRequest(req))
      throw new CacheMiss();
    let resHeaders, resRanges, cached = await this.storage.get(cacheKey, ({ size, headers }) => {
      resHeaders = new Headers(headers);
      let contentType = resHeaders.get("Content-Type"), rangeHeader = req.headers.get("Range");
      if (rangeHeader !== null && (resRanges = parseRanges(rangeHeader, size), resRanges === void 0))
        throw new RangeNotSatisfiable(size);
      return {
        ranges: resRanges,
        contentLength: size,
        contentType: contentType ?? void 0
      };
    });
    if (cached?.metadata === void 0)
      throw new CacheMiss();
    return assert(resHeaders !== void 0), resHeaders.set("CF-Cache-Status", "HIT"), resRanges ??= [], getMatchResponse(req.headers, {
      status: cached.metadata.status,
      headers: resHeaders,
      ranges: resRanges,
      body: cached.value,
      totalSize: cached.metadata.size
    });
  };
  put = async (req) => {
    await this.#maybeWarnUsage(req);
    let cacheKey = getCacheKey(req);
    if (isSitesRequest(req))
      throw new CacheMiss();
    assert(req.body !== null);
    let res = await parseHttpResponse(req.body), body = res.body;
    assert(body !== null);
    let { storable, expiration, headers } = getExpiration(
      this.timers,
      req,
      res
    );
    if (!storable) {
      try {
        await body.pipeTo(new WritableStream());
      } catch {
      }
      throw new StorageFailure();
    }
    let contentLength = parseInt(res.headers.get("Content-Length")), sizePromise;
    if (Number.isNaN(contentLength)) {
      let stream = new SizingStream();
      body = body.pipeThrough(stream), sizePromise = stream.size;
    } else
      sizePromise = Promise.resolve(contentLength);
    let metadata = sizePromise.then((size) => ({
      headers: Object.entries(headers),
      status: res.status,
      size
    }));
    return await this.storage.put({
      key: cacheKey,
      value: body,
      expiration: this.timers.now() + expiration,
      metadata
    }), new Response(null, { status: 204 });
  };
  delete = async (req) => {
    await this.#maybeWarnUsage(req);
    let cacheKey = getCacheKey(req);
    if (!await this.storage.delete(cacheKey))
      throw new PurgeFailure();
    return new Response(null);
  };
};
__decorateClass([
  GET()
], CacheObject.prototype, "match", 2), __decorateClass([
  PUT()
], CacheObject.prototype, "put", 2), __decorateClass([
  PURGE()
], CacheObject.prototype, "delete", 2);
export {
  CacheObject,
  parseHttpResponse
};
//# sourceMappingURL=cache.worker.js.map
//# sourceURL=file:///C:/Users/joshr/AppData/Local/Temp/bunx-3240478352-selflare@latest/node_modules/selflare/dist/workers/cache/cache.worker.js                 b   	   �   CacheObject     miniflare-CacheObject   cache:storage               1   �   4                                             -   �   4                                      MINIFLARE_BLOBS    r           cache:storage   MINIFLARE_LOOPBACK         J           loopback        loopback                )   z                                        	   Z                   MF-CF-Blob      localhost:8080  internet        	                    :      B   public  private                   �          ]  Z'  �  �.  �  Z'  1
  B3  a  R/  U  �?  M  rI  �  2/  �  2-  �  �-  }!  "*  $  �)  �&  �*  ])  �?  Y-  �?  U1  "*  �3  B*  �6  r.  y9  Z  M;  �)  �=  r?  �A  �$  D  .  �F  �&  iI  �-  AL  Z&  �N  :B  �R  �*  mU  �+  %X  j,  �Z  �%  A]  �%  �_  ;  Ec  �  �d  B*  Yg  �'  �i  Z'  El  �?  Ap  �;  �s  �;  �w  �*  Yz  R/  M}  �/  I�  b<  �  �V  q�  �:  �  Z:  ��  �*  e�  Z'  ٕ  <  ��  <  Q�  <  �  �(  ��  �  =�  Z(  ��  *  a�  
>  A�  A  Q�  RA  e�  �  =�  �  ɸ  <  ��  B<  E�  �/  A�  
"  a�  �=  =�  *  ��  :'  I�  �@  U�  :C  ��  �  }�  �<  A�  �=  �  %  i�  �:  �  z  U�    ��  Z1  ��  �=  ��  RA  ��  z  ��  �A  ��  �  ��  �=  i�  �  % ;  � �;  � �F  � �(  y �  % :'  � j  ) �@  1 F  � R  A 
?  1# J  �$ ;  �( 2A  �, �  I. :  )0 �>  4 2  �5 �;  �9   	; �=  �> B  C �  �D @  �H �?  �L �>  �P   QR �C  �V "  	X �;  �[ �  I] �<  a �  ib �;  !f �;  �i �  Uk �  �l �<  �p �   �r �   �t �  5v B<  �y ;  �} "   j=  � �  �� �<  M� *  ݉ 
  }� �=  Y� �=  5� 
  Ք b  Y� B<  � �>  � 2  �� �  A� �  ͢ �<  �� �<  U� J  �� �?  � �  �� �=  �� :'  � �<  ͻ 
  -----BEGIN CERTIFICATE-----
MIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkGA1UEBhMC
QkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jvb3QgQ0ExGzAZBgNV
BAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAwMDBaFw0yODAxMjgxMjAwMDBa
MFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdS
b290IENBMRswGQYDVQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUA
A4IBDwAwggEKAoIBAQDaDuaZjc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtI
K+6NiY6arymAZavpxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCO
XkNz8kHp1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG
snUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJU26Qzns3
dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N89iFo7+ryUp9/k5DP
AgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRg
e2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEA1nPnfE920I2/7LqivjTF
KDK1fPxsnCwrvQmeU79rXqoRSLblCKOzyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY7
76BQVvnGCv04zcQLcFGUl5gE38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9
LhJIZJrglfCm7ymPAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr
+WymXUadDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME
HMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIEKjCCAxKgAwIBAgIEOGPe+DANBgkqhkiG9w0BAQUFADCBtDEUMBIGA1UEChMLRW50cnVz
dC5uZXQxQDA+BgNVBAsUN3d3dy5lbnRydXN0Lm5ldC9DUFNfMjA0OCBpbmNvcnAuIGJ5IHJl
Zi4gKGxpbWl0cyBsaWFiLikxJTAjBgNVBAsTHChjKSAxOTk5IEVudHJ1c3QubmV0IExpbWl0
ZWQxMzAxBgNVBAMTKkVudHJ1c3QubmV0IENlcnRpZmljYXRpb24gQXV0aG9yaXR5ICgyMDQ4
KTAeFw05OTEyMjQxNzUwNTFaFw0yOTA3MjQxNDE1MTJaMIG0MRQwEgYDVQQKEwtFbnRydXN0
Lm5ldDFAMD4GA1UECxQ3d3d3LmVudHJ1c3QubmV0L0NQU18yMDQ4IGluY29ycC4gYnkgcmVm
LiAobGltaXRzIGxpYWIuKTElMCMGA1UECxMcKGMpIDE5OTkgRW50cnVzdC5uZXQgTGltaXRl
ZDEzMDEGA1UEAxMqRW50cnVzdC5uZXQgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgKDIwNDgp
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArU1LqRKGsuqjIAcVFmQqK0vRvwtK
TY7tgHalZ7d4QMBzQshowNtTK91euHaYNZOLGp18EzoOH1u3Hs/lJBQesYGpjX24zGtLA/EC
DNyrpUAkAH90lKGdCCmziAv1h3edVc3kw37XamSrhRSGlVuXMlBvPci6Zgzj/L24ScF2iUkZ
/cCovYmjZy/Gn7xxGWC4LeksyZB2ZnuU4q941mVTXTzWnLLPKQP5L6RQstRIzgUyVYr9smRM
DuSYB3Xbf9+5CFVghTAp+XtIpGmG4zU/HoZdenoVve8AjhUiVBcAkCaTvA5JaJG/+EfTnZVC
wQ5N328mz8MYIWJmQ3DW1cAH4QIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQUVeSB0RGAvtiJuQijMfmhJAkWuXAwDQYJKoZIhvcNAQEFBQAD
ggEBADubj1abMOdTmXx6eadNl9cZlZD7Bh/KM3xGY4+WZiT6QBshJ8rmcnPyT/4xmf3IDExo
U8aAghOY+rat2l098c5u9hURlIIM7j+VrxGrD9cv3h8Dj1csHsm7mhpElesYT6YfzX1XEC+b
BAlahLVu2B064dae0Wx5XnkcFMXj0EyTO2U87d89vqbllRrDtRnDvV5bu/8j72gZyxKTJ1wD
LW8w0B62GqzeWvfRqqgnpv55gcR5mTNXuhKwqeBCbJPKVt7+bYQLCIt+jerXmCHG8+c8eS9e
nNFMFY3h7CI3zJpDC5fcgJCNs2ebb0gIFVbPv/ErfF6adulZkMV8gzURZVE=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIDdzCCAl+gAwIBAgIEAgAAuTANBgkqhkiG9w0BAQUFADBaMQswCQYDVQQGEwJJRTESMBAG
A1UEChMJQmFsdGltb3JlMRMwEQYDVQQLEwpDeWJlclRydXN0MSIwIAYDVQQDExlCYWx0aW1v
cmUgQ3liZXJUcnVzdCBSb290MB4XDTAwMDUxMjE4NDYwMFoXDTI1MDUxMjIzNTkwMFowWjEL
MAkGA1UEBhMCSUUxEjAQBgNVBAoTCUJhbHRpbW9yZTETMBEGA1UECxMKQ3liZXJUcnVzdDEi
MCAGA1UEAxMZQmFsdGltb3JlIEN5YmVyVHJ1c3QgUm9vdDCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBAKMEuyKrmD1X6CZymrV51Cni4eiVgLGw41uOKymaZN+hXe2wCQVt2ygu
zmKiYv60iNoS6zjrIZ3AQSsBUnuId9Mcj8e6uYi1agnnc+gRQKfRzMpijS3ljwumUNKoUMMo
6vWrJYeKmpYcqWe4PwzV9/lSEy/CG9VwcPCPwBLKBsua4dnKM3p31vjsufFoREJIE9LAwqSu
XmD+tqYF/LTdB1kC1FkYmGP1pWPgkAx9XbIGevOF6uvUA65ehD5f/xXtabz5OTZydc93Uk3z
yZAsuT3lySNTPx8kmCFcB5kpvcY67Oduhjprl3RjM71oGDHweI12v/yejl0qhqdNkNwnGjkC
AwEAAaNFMEMwHQYDVR0OBBYEFOWdWTCCR1jMrPoIVDaGezq1BE3wMBIGA1UdEwEB/wQIMAYB
Af8CAQMwDgYDVR0PAQH/BAQDAgEGMA0GCSqGSIb3DQEBBQUAA4IBAQCFDF2O5G9RaEIFoN27
TyclhAO992T9Ldcw46QQF+vaKSm2eT929hkTI7gQCvlYpNRhcL0EYWoSihfVCr3FvDB81ukM
JY2GQE/szKN+OMY3EU/t3WgxjkzSswF07r51XgdIGn9w/xZchMB5hbgF/X++ZRGjD8ACtPhS
NzkE1akxehi/oCr0Epn3o0WC4zxe9Z2etciefC7IpJ5OCBRLbf1wbWsaY71k5h+3zvDyny67
G7fyUIhzksLi4xaNmjICq44Y3ekQEe5+NauQrz4wlHrQMz2nZQ/1/I6eYs9HRCwBXbsdtTLS
R9I4LtD+gdwyah617jzV/OeBHRnDJELqYzmp
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIEkTCCA3mgAwIBAgIERWtQVDANBgkqhkiG9w0BAQUFADCBsDELMAkGA1UEBhMCVVMxFjAU
BgNVBAoTDUVudHJ1c3QsIEluYy4xOTA3BgNVBAsTMHd3dy5lbnRydXN0Lm5ldC9DUFMgaXMg
aW5jb3Jwb3JhdGVkIGJ5IHJlZmVyZW5jZTEfMB0GA1UECxMWKGMpIDIwMDYgRW50cnVzdCwg
SW5jLjEtMCsGA1UEAxMkRW50cnVzdCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4X
DTA2MTEyNzIwMjM0MloXDTI2MTEyNzIwNTM0MlowgbAxCzAJBgNVBAYTAlVTMRYwFAYDVQQK
Ew1FbnRydXN0LCBJbmMuMTkwNwYDVQQLEzB3d3cuZW50cnVzdC5uZXQvQ1BTIGlzIGluY29y
cG9yYXRlZCBieSByZWZlcmVuY2UxHzAdBgNVBAsTFihjKSAyMDA2IEVudHJ1c3QsIEluYy4x
LTArBgNVBAMTJEVudHJ1c3QgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBALaVtkNC+sZtKm9I35RMOVcF7sN5EUFoNu3s/poB
j6E4KPz3EEZmLk0eGrEaTsbRwJWIsMn/MYszA9u3g3s+IIRe7bJWKKf44LlAcTfFy0cOlypo
wCKVYhXbR9n10Cv/gkvJrT7eTNuQgFA/CYqEAOwwCj0Yzfv9KlmaI5UXLEWeH25DeW0MXJj+
SKfFI0dcXv1u5x609mhF0YaDW6KKjbHjKYD+JXGIrb68j6xSlkuqUY3kEzEZ6E5Nn9uss2rV
vDlUccp6en+Q3X0dgNmBu1kmwhH+5pPi94DkZfs0Nw4pgHBNrziGLp5/V6+eF67rHMsoIV+2
HNjnogQi+dPa2MsCAwEAAaOBsDCBrTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB
/zArBgNVHRAEJDAigA8yMDA2MTEyNzIwMjM0MlqBDzIwMjYxMTI3MjA1MzQyWjAfBgNVHSME
GDAWgBRokORnpKZTgMeGZqTx90tD+4S9bTAdBgNVHQ4EFgQUaJDkZ6SmU4DHhmak8fdLQ/uE
vW0wHQYJKoZIhvZ9B0EABBAwDhsIVjcuMTo0LjADAgSQMA0GCSqGSIb3DQEBBQUAA4IBAQCT
1DCw1wMgKtD5Y+iRDAUgqV8ZyntyTtSx29CW+1RaGSwMCPeyvIWonX9tO1KzKtvn1ISMY/YP
yyYBkVBs9F8U4pN0wBOeMDpQ47RgxRzwIkSNcUesyBrJ6ZuaAGAT/3B+XxFNSRuzFVJ7yVTa
v52Vr2ua2J7p8eRDjeIRRDq/r72DQnNSi6q7pynP9WQcCk3RvKqsnyrQ/39/2n3qse0wJcGE
2jTSW3iDVuycNsMm4hH2Z0kdkquM++v/eu6FSqdQgPCnXEqULl8FmTxSQeDNtGPPAUO6nIPc
j2A781q0tHuu2guQOHXvgR1m0vdXcDazv/wor3ElhVsT/h5/WrQ8
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIEMjCCAxqgAwIBAgIBATANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UE
CAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21v
ZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTA0
MDEwMTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowezELMAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdy
ZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENB
IExpbWl0ZWQxITAfBgNVBAMMGEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAL5AnfRu4ep2hxxNRUSOvkbIgwadwSr+GB+O5AL686td
UIoWMQuaBtDFcCLNSS1UY8y2bmhGC1Pqy0wkwLxyTurxFa70VJoSCsN6sjNg4tqJVfMiWPPe
3M/vg4aijJRPn2jymJBGhCfHdr/jzDUsi14HZGWCwEiwqJH5YZ92IFCokcdmtet4YgNW8Ioa
E+oxox6gmf049vYnMlhvB/VruPsUK6+3qszWY19zjNoFmag4qMsXeDZRrOme9Hg6jc8P2ULi
mAyrL58OAd7vn5lJ8S3frHRNG5i1R8XlKdH5kBjHYpy+g8cmez6KJcfA3Z3mNWgQIJ2P2N7S
w4ScDV7oL8kCAwEAAaOBwDCBvTAdBgNVHQ4EFgQUoBEKIz6W8Qfs4q8p74Klf9AwpLQwDgYD
VR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wewYDVR0fBHQwcjA4oDagNIYyaHR0cDov
L2NybC5jb21vZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNqA0oDKGMGh0
dHA6Ly9jcmwuY29tb2RvLm5ldC9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDANBgkqhkiG
9w0BAQUFAAOCAQEACFb8AvCb6P+k+tZ7xkSAzk/ExfYAWMymtrwUSWgEdujm7l3sAg9g1o1Q
GE8mTgHj5rCl7r+8dFRBv/38ErjHT1r0iWAFf2C3BUrz9vHCv8S5dIa2LX1rzNLzRt0vxuBq
w8M0Ayx9lt1awg6nCpnBBYurDC/zXDrPbDdVCYfeU0BsWO/8tqtlbgT2G9w84FoVxp7Z8VlI
MCFlA2zs6SFz7JsDoeA3raAVGI/6ugLOpyypEBMs1OUIJqsil2D4kF501KKaU73yqWjgom7C
12yxow+ev+to51byrvLjKzg6CYG1a4XXvi3tPxq3smPi9WIsgtRqAEFQ8TmDn5XpNpaYbg==
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFtzCCA5+gAwIBAgICBQkwDQYJKoZIhvcNAQEFBQAwRTELMAkGA1UEBhMCQk0xGTAXBgNV
BAoTEFF1b1ZhZGlzIExpbWl0ZWQxGzAZBgNVBAMTElF1b1ZhZGlzIFJvb3QgQ0EgMjAeFw0w
NjExMjQxODI3MDBaFw0zMTExMjQxODIzMzNaMEUxCzAJBgNVBAYTAkJNMRkwFwYDVQQKExBR
dW9WYWRpcyBMaW1pdGVkMRswGQYDVQQDExJRdW9WYWRpcyBSb290IENBIDIwggIiMA0GCSqG
SIb3DQEBAQUAA4ICDwAwggIKAoICAQCaGMpLlA0ALa8DKYrwD4HIrkwZhR0In6spRIXzL4Gt
Mh6QRr+jhiYaHv5+HBg6XJxgFyo6dIMzMH1hVBHL7avg5tKifvVrbxi3Cgst/ek+7wrGsxDp
3MJGF/hd/aTa/55JWpzmM+Yklvc/ulsrHHo1wtZn/qtmUIttKGAr79dgw8eTvI02kfN/+NsR
E8Scd3bBrrcCaoF6qUWD4gXmuVbBlDePSHFjIuwXZQeVikvfj8ZaCuWw419eaxGrDPmF60Tp
+ARz8un+XJiM9XOva7R+zdRcAitMOeGylZUtQofX1bOQQ7dsE/He3fbE+Ik/0XX1ksOR1YqI
0JDs3G3eicJlcZaLDQP9nL9bFqyS2+r+eXyt66/3FsvbzSUr5R/7mp/iUcw6UwxI5g69ybR2
BlLmEROFcmMDBOAENisgGQLodKcftslWZvB1JdxnwQ5hYIizPtGo/KPaHbDRsSNU30R2be1B
2MGyIrZTHN81Hdyhdyox5C315eXbyOD/5YDXC2Og/zOhD7osFRXql7PSorW+8oyWHhqPHWyk
YTe5hnMz15eWniN9gqRMgeKh0bpnX5UHoycR7hYQe7xFSkyyBNKr79X9DFHOUGoIMfmR2gyP
ZFwDwzqLID9ujWc9Otb+fVuIyV77zGHcizN300QyNQliBJIWENieJ0f7OyHj+OsdWwIDAQAB
o4GwMIGtMA8GA1UdEwEB/wQFMAMBAf8wCwYDVR0PBAQDAgEGMB0GA1UdDgQWBBQahGK8SEwz
JQTU7tD2A8QZRtGUazBuBgNVHSMEZzBlgBQahGK8SEwzJQTU7tD2A8QZRtGUa6FJpEcwRTEL
MAkGA1UEBhMCQk0xGTAXBgNVBAoTEFF1b1ZhZGlzIExpbWl0ZWQxGzAZBgNVBAMTElF1b1Zh
ZGlzIFJvb3QgQ0EgMoICBQkwDQYJKoZIhvcNAQEFBQADggIBAD4KFk2fBluornFdLwUvZ+YT
RYPENvbzwCYMDbVHZF34tHLJRqUDGCdViXh9duqWNIAXINzng/iN/Ae42l9NLmeyhP3ZRPx3
UIHmfLTJDQtyU/h2BwdBR5YM++CCJpNVjP4iH2BlfF/nJrP3MpCYUNQ3cVX2kiF495V5+vgt
JodmVjB3pjd4M1IQWK4/YY7yarHvGH5KWWPKjaJW1acvvFYfzznB4vsKqBUsfU16Y8Zsl0Q8
0m/DShcK+JDSV6IZUaUtl0HaB0+pUNqQjZRG4T7wlP0QADj1O+hA4bRuVhogzG9Yje0uRY/W
6ZM/57Es3zrWIozchLsib9D45MY56QSIPMO661V6bYCZJPVsAfv4l7CUW+v90m/xd2gNNWQj
rLhVoQPRTUIZ3Ph1WVaj+ahJefivDrkRoHy3au000LYmYjgahwz46P0u05B/B5EqHdZ+XIWD
mbA4CD/pXvk1B+TJYm5Xf6dQlfe6yJvmjqIBxdZmv3lh8zwc4bmCXF2gw+nYSL0ZohEUGW6y
hhtoPkg3Goi3XZZenMfvJ2II4pEZXNLxId26F0KCl3GBUzGpn/Z9Yr9y4aOTHcyKJloJONDO
1w2AFrR4pTqHTI2KpdVGl/IsELm8VCLAAVBpQ570su9t+Oza8eOx79+Rj1QqCyXBJhnEUhAF
ZdWCEOrCMc0u
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIGnTCCBIWgAwIBAgICBcYwDQYJKoZIhvcNAQEFBQAwRTELMAkGA1UEBhMCQk0xGTAXBgNV
BAoTEFF1b1ZhZGlzIExpbWl0ZWQxGzAZBgNVBAMTElF1b1ZhZGlzIFJvb3QgQ0EgMzAeFw0w
NjExMjQxOTExMjNaFw0zMTExMjQxOTA2NDRaMEUxCzAJBgNVBAYTAkJNMRkwFwYDVQQKExBR
dW9WYWRpcyBMaW1pdGVkMRswGQYDVQQDExJRdW9WYWRpcyBSb290IENBIDMwggIiMA0GCSqG
SIb3DQEBAQUAA4ICDwAwggIKAoICAQDMV0IWVJzmmNPTTe7+7cefQzlKZbPoFog02w1ZkXTP
krgEQK0CSzGrvI2RaNggDhoB4hp7Thdd4oq3P5kazethq8Jlph+3t723j/z9cI8LoGe+AaJZ
z3HmDyl2/7FWeUUrH556VOijKTVopAFPD6QuN+8bv+OPEKhyq1hX51SGyMnzW9os2l2Objyj
Ptr7guXd8lyyBTNvijbO0BNO/79KDDRMpsMhvVAEVeuxu537RR5kFd5VAYwCdrXLoT9Cabwv
vWhDFlaJKjdhkf2mrk7AyxRllDdLkgbvBNDInIjbC3uBr7E9KsRlOni27tyAsdLTmZw67mta
a7ONt9XOnMK+pUsvFrGeaDsGb659n/je7Mwpp5ijJUMv7/FfJuGITfhebtfZFG4ZM2mnO4SJ
k8RTVROhUXhA+LjJou57ulJCg54U7QVSWllWp5f8nT8KKdjcT5EOE7zelaTfi5m+rJsziO+1
ga8bxiJTyPbH7pcUsMV8eFLI8M5ud2CEpukqdiDtWAEXMJPpGovgc2PZapKUSU60rUqFxKMi
MPwJ7Wgic6aIDFUhWMXhOp8q3crhkODZc6tsgLjoC2SToJyMGf+z0gzskSaHirOi4XCPLArl
zW1oUevaPwV/izLmE1xr/l9A4iLItLRkT9a6fUg+qGkM17uGcclzuD87nSVL2v9A6wIDAQAB
o4IBlTCCAZEwDwYDVR0TAQH/BAUwAwEB/zCB4QYDVR0gBIHZMIHWMIHTBgkrBgEEAb5YAAMw
gcUwgZMGCCsGAQUFBwICMIGGGoGDQW55IHVzZSBvZiB0aGlzIENlcnRpZmljYXRlIGNvbnN0
aXR1dGVzIGFjY2VwdGFuY2Ugb2YgdGhlIFF1b1ZhZGlzIFJvb3QgQ0EgMyBDZXJ0aWZpY2F0
ZSBQb2xpY3kgLyBDZXJ0aWZpY2F0aW9uIFByYWN0aWNlIFN0YXRlbWVudC4wLQYIKwYBBQUH
AgEWIWh0dHA6Ly93d3cucXVvdmFkaXNnbG9iYWwuY29tL2NwczALBgNVHQ8EBAMCAQYwHQYD
VR0OBBYEFPLAE+CCQz777i9nMpY1XNu4ywLQMG4GA1UdIwRnMGWAFPLAE+CCQz777i9nMpY1
XNu4ywLQoUmkRzBFMQswCQYDVQQGEwJCTTEZMBcGA1UEChMQUXVvVmFkaXMgTGltaXRlZDEb
MBkGA1UEAxMSUXVvVmFkaXMgUm9vdCBDQSAzggIFxjANBgkqhkiG9w0BAQUFAAOCAgEAT62g
LEz6wPJv92ZVqyM07ucp2sNbtrCD2dDQ4iH782CnO11gUyeim/YIIirnv6By5ZwkajGxkHon
24QRiSemd1o417+shvzuXYO8BsbRd2sPbSQvS3pspweWyuOEn62Iix2rFo1bZhfZFvSLgNLd
+LJ2w/w4E6oM3kJpK27zPOuAJ9v1pkQNn1pVWQvVDVJIxa6f8i+AxeoyUDUSly7B4f/xI4hR
OJ/yZlZ25w9Rl6VSDE1JUZU2Pb+iSwwQHYaZTKrzchGT5Or2m9qoXadNt54CrnMAyNojA+j5
6hl0YgCUyyIgvpSnWbWCar6ZeXqp8kokUvd0/bpO5qgdAm6xDYBEwa7TIzdfu4V8K5Iu6H6l
i92Z4b8nby1dqnuH/grdS/yO9SbkbnBCbjPsMZ57k8HkyWkaPcBrTiJt7qtYTcbQQcEr6k8S
h17rRdhs9ZgC06DYVYoGmRmioHfRMJ6szHXug/WwYjnPbFfiTNKRCw51KBuav/0aQ/HKd/s7
j2G4aSgWQgRecCocIdiP4b0jWy10QJLZYxkNc91pvGJHvOB0K7Lrfb5BG7XARsWhIstfTsEo
kt4YutUqKLsRixeTmJlglFwjz1onl14LBQaTNx47aTbrqZ5hHY8y2o4M1nQ+ewkk2gF3R8Q7
zTSMmfXK4SVhM7JZG+Ju1zdXtg2pEto=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIEMDCCAxigAwIBAgIQUJRs7Bjq1ZxN1ZfvdY+grTANBgkqhkiG9w0BAQUFADCBgjELMAkG
A1UEBhMCVVMxHjAcBgNVBAsTFXd3dy54cmFtcHNlY3VyaXR5LmNvbTEkMCIGA1UEChMbWFJh
bXAgU2VjdXJpdHkgU2VydmljZXMgSW5jMS0wKwYDVQQDEyRYUmFtcCBHbG9iYWwgQ2VydGlm
aWNhdGlvbiBBdXRob3JpdHkwHhcNMDQxMTAxMTcxNDA0WhcNMzUwMTAxMDUzNzE5WjCBgjEL
MAkGA1UEBhMCVVMxHjAcBgNVBAsTFXd3dy54cmFtcHNlY3VyaXR5LmNvbTEkMCIGA1UEChMb
WFJhbXAgU2VjdXJpdHkgU2VydmljZXMgSW5jMS0wKwYDVQQDEyRYUmFtcCBHbG9iYWwgQ2Vy
dGlmaWNhdGlvbiBBdXRob3JpdHkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCY
JB69FbS638eMpSe2OAtp87ZOqCwuIR1cRN8hXX4jdP5efrRKt6atH67gBhbim1vZZ3RrXYCP
KZ2GG9mcDZhtdhAoWORlsH9KmHmf4MMxfoArtYzAQDsRhtDLooY2YKTVMIJt2W7QDxIEM5df
T2Fa8OT5kavnHTu86M/0ay00fOJIYRyO82FEzG+gSqmUsE3a56k0enI4qEHMPJQRfevIpoy3
hsvKMzvZPTeL+3o+hiznc9cKV6xkmxnr9A8ECIqsAxcZZPRaJSKNNCyy9mgdEm3Tih4U2sSP
puIjhdV6Db1q4Ons7Be7QhtnqiXtRYMh/MHJfNViPvryxS3T/dRlAgMBAAGjgZ8wgZwwEwYJ
KwYBBAGCNxQCBAYeBABDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
BBYEFMZPoj0GY4QJnM5i5ASsjVy16bYbMDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9jcmwu
eHJhbXBzZWN1cml0eS5jb20vWEdDQS5jcmwwEAYJKwYBBAGCNxUBBAMCAQEwDQYJKoZIhvcN
AQEFBQADggEBAJEVOQMBG2f7Shz5CmBbodpNl2L5JFMn14JkTpAuw0kbK5rc/Kh4ZzXxHfAR
vbdI4xD2Dd8/0sm2qlWkSLoC295ZLhVbO50WfUfXN+pfTXYSNrsf16GBBEYgoyxtqZ4Bfj8p
zgCT3/3JknOJiWSe5yvkHJEs0rnOfc5vMZnT5r7SHpDwCRR5XCOrTdLaIR9NmXmd4c8nnxCb
HIgNsIpkQTG4DmyQJKSbXHGPurt+HBvbaoAPIbzp26a3QPSyi6mx5O+aGtA9aZnuqCij4Tyz
8LIRnM98QObd50N9otg6tamN8jSZxNQQ4Qb9CYQQO+7ETPTsJ3xCwnR8gooJybQDJbw=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIEADCCAuigAwIBAgIBADANBgkqhkiG9w0BAQUFADBjMQswCQYDVQQGEwJVUzEhMB8GA1UE
ChMYVGhlIEdvIERhZGR5IEdyb3VwLCBJbmMuMTEwLwYDVQQLEyhHbyBEYWRkeSBDbGFzcyAy
IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTA0MDYyOTE3MDYyMFoXDTM0MDYyOTE3MDYy
MFowYzELMAkGA1UEBhMCVVMxITAfBgNVBAoTGFRoZSBHbyBEYWRkeSBHcm91cCwgSW5jLjEx
MC8GA1UECxMoR28gRGFkZHkgQ2xhc3MgMiBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASAw
DQYJKoZIhvcNAQEBBQADggENADCCAQgCggEBAN6d1+pXGEmhW+vXX0iG6r7d/+TvZxz0ZWiz
V3GgXne77ZtJ6XCAPVYYYwhv2vLM0D9/AlQiVBDYsoHUwHU9S3/Hd8M+eKsaA7Ugay9qK7HF
iH7Eux6wwdhFJ2+qN1j3hybX2C32qRe3H3I2TqYXP2WYktsqbl2i/ojgC95/5Y0V4evLOtXi
EqITLdiOr18SPaAIBQi2XKVlOARFmR6jYGB0xUGlcmIbYsUfb18aQr4CUWWoriMYavx4A6lN
f4DD+qta/KFApMoZFv6yyO9ecw3ud72a9nmYvLEHZ6IVDd2gWMZEewo+YihfukEHU1jPEX44
dMX4/7VpkI+EdOqXG68CAQOjgcAwgb0wHQYDVR0OBBYEFNLEsNKR1EwRcbNhyz2h/t2oatTj
MIGNBgNVHSMEgYUwgYKAFNLEsNKR1EwRcbNhyz2h/t2oatTjoWekZTBjMQswCQYDVQQGEwJV
UzEhMB8GA1UEChMYVGhlIEdvIERhZGR5IEdyb3VwLCBJbmMuMTEwLwYDVQQLEyhHbyBEYWRk
eSBDbGFzcyAyIENlcnRpZmljYXRpb24gQXV0aG9yaXR5ggEAMAwGA1UdEwQFMAMBAf8wDQYJ
KoZIhvcNAQEFBQADggEBADJL87LKPpH8EsahB4yOd6AzBhRckB4Y9wimPQoZ+YeAEW5p5JYX
MP80kWNyOO7MHAGjHZQopDH2esRU1/blMVgDoszOYtuURXO1v0XJJLXVggKtI3lpjbi2Tc7P
TMozI+gciKqdi0FuFskg5YmezTvacPd+mSYgFFQlq25zheabIZ0KbIIOqPjCDPoQHmyW74cN
xA9hi63ugyuV+I6ShHI56yDqg+2DzZduCLzrTia2cyvk0/ZM/iZx4mERdEr/VxqHD3VILs9R
aRegAhJhldXRQLIQTO7ErBBDpqWeCtWVYpoNz4iCxTIM5CufReYNnyicsbkqWletNw+vHX/b
vZ8=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIEDzCCAvegAwIBAgIBADANBgkqhkiG9w0BAQUFADBoMQswCQYDVQQGEwJVUzElMCMGA1UE
ChMcU3RhcmZpZWxkIFRlY2hub2xvZ2llcywgSW5jLjEyMDAGA1UECxMpU3RhcmZpZWxkIENs
YXNzIDIgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMDQwNjI5MTczOTE2WhcNMzQwNjI5
MTczOTE2WjBoMQswCQYDVQQGEwJVUzElMCMGA1UEChMcU3RhcmZpZWxkIFRlY2hub2xvZ2ll
cywgSW5jLjEyMDAGA1UECxMpU3RhcmZpZWxkIENsYXNzIDIgQ2VydGlmaWNhdGlvbiBBdXRo
b3JpdHkwggEgMA0GCSqGSIb3DQEBAQUAA4IBDQAwggEIAoIBAQC3Msj+6XGmBIWtDBFk385N
78gDGIc/oav7PKaf8MOh2tTYbitTkPskpD6E8J7oX+zlJ0T1KKY/e97gKvDIr1MvnsoFAZMe
j2YcOadN+lq2cwQlZut3f+dZxkqZJRRU6ybH838Z1TBwj6+wRir/resp7defqgSHo9T5iaU0
X9tDkYI22WY8sbi5gv2cOj4QyDvvBmVmepsZGD3/cVE8MC5fvj13c7JdBmzDI1aaK4Umkhyn
ArPkPw2vCHmCuDY96pzTNbO8acr1zJ3o/WSNF4Azbl5KXZnJHoe0nRrA1W4TNSNe35tfPe/W
93bC6j67eA0cQmdrBNj41tpvi/JEoAGrAgEDo4HFMIHCMB0GA1UdDgQWBBS/X7fRzt0fhvRb
Vazc1xDCDqmI5zCBkgYDVR0jBIGKMIGHgBS/X7fRzt0fhvRbVazc1xDCDqmI56FspGowaDEL
MAkGA1UEBhMCVVMxJTAjBgNVBAoTHFN0YXJmaWVsZCBUZWNobm9sb2dpZXMsIEluYy4xMjAw
BgNVBAsTKVN0YXJmaWVsZCBDbGFzcyAyIENlcnRpZmljYXRpb24gQXV0aG9yaXR5ggEAMAwG
A1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAAWdP4id0ckaVaGsafPzWdqbAYcaT1ep
oXkJKtv3L7IezMdeatiDh6GX70k1PncGQVhiv45YuApnP+yz3SFmH8lU+nLMPUxA2IGvd56D
eruix/U0F47ZEUD0/CwqTRV/p2JdLiXTAAsgGh1o+Re49L2L7ShZ3U0WixeDyLJlxy16paq8
U4Zt3VekyvggQQto8PT7dL5WXXp59fkdheMtlb71cZBDzI0fmgAKhynpVSJYACPq4xJDKVtH
CN2MQWplBqjlIapBtJUhlbl90TSrE9atvNziPTnNvT51cKEYWQPJIrSPnNVeKtelttQKbfi3
QBFGmh95DmK/D5fs4C8fF5Q=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIDtzCCAp+gAwIBAgIQDOfg5RfYRv6P5WD8G/AwOTANBgkqhkiG9w0BAQUFADBlMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMDYxMTEwMDAw
MDAwWhcNMzExMTEwMDAwMDAwWjBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1
cmVkIElEIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCtDhXO5EOA
XLGH87dg+XESpa7cJpSIqvTO9SA5KFhgDPiA2qkVlTJhPLWxKISKityfCgyDF3qPkKyK53lT
XDGEKvYPmDI2dsze3Tyoou9q+yHyUmHfnyDXH+Kx2f4YZNISW1/5WBg1vEfNoTb5a3/UsDg+
wRvDjDPZ2C8Y/igPs6eD1sNuRMBhNZYW/lmci3Zt1/GiSw0r/wty2p5g0I6QNcZ4VYcgoc/l
bQrISXwxmDNsIumH0DJaoroTghHtORedmTpyoeb6pNnVFzF1roV9Iq4/AUaG9ih5yLHa5FcX
xH4cDrC0kqZWs72yl+2qp/C3xag/lRbQ/6GW6whfGHdPAgMBAAGjYzBhMA4GA1UdDwEB/wQE
AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRF66Kv9JLLgjEtUYunpyGd823IDzAf
BgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAog68
3+Lt8ONyc3pklL/3cmbYMuRCdWKuh+vy1dneVrOfzM4UKLkNl2BcEkxY5NM9g0lFWJc1aRqo
R+pWxnmrEthngYTffwk8lOa4JiwgvT2zKIn3X/8i4peEH+ll74fg38FnSbNd67IJKusm7Xi+
fT8r87cmNW1fiQG2SVufAQWbqz0lwcy2f8Lxb4bG+mRo64EtlOtCt/qMHt1i8b5QZ7dsvfPx
H2sMNgcWfzd8qVttevESRmCD1ycEvkvOl77DZypoEd+A5wwzZr8TDRRu838fYxAe+o0bJW1s
j6W3YQGx0qMmoRBxna3iw/nDmVG3KwcIzi7mULKn+gpFL6Lw8g==
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBhMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBDQTAeFw0wNjExMTAwMDAwMDBa
Fw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBS
b290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKP
C3eQyaKl7hLOllsBCSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscF
s3YnFo97nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7PT19sdl6g
SzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4gdW7jVg/tRvoSSii
cNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAOBgNVHQ8BAf8EBAMCAYYwDwYD
VR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbRTLtm8KPiGxvDl7I90VUwHwYDVR0jBBgw
FoAUA95QNVbRTLtm8KPiGxvDl7I90VUwDQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1E
nE9SsPTfrgT1eXkIoyQY/EsrhMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDi
qw8cvpOp/2PV5Adg06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBA
I+0tKIJFPnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQkCAUw7C29
C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBsMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5jZSBFViBSb290IENBMB4XDTA2
MTExMDAwMDAwMFoXDTMxMTExMDAwMDAwMFowbDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNl
cnQgSGlnaCBBc3N1cmFuY2UgRVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBAMbM5XPm+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlB
WTrT3JTWPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wblCJEM
xChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFBIk5lYYeB
QVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3hzBWBOURtCmAEvF5
OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsgEsxBu24LUTi4S8sCAwEAAaNj
MGEwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9H
AdSYJhoIAu9jZCvDMB8GA1UdIwQYMBaAFLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3
DQEBBQUAA4IBAQAcGgaX3NecnzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1
ntlMMUu4kehDLI6zeM7b41N5cdblIZQB2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VH
MWEZ71jFhS9OMPagMRYjyOfiZRYzy78aG6A9+MpeizGLYAiJLQwGXFK3xPkKmNEVX58Svnw2
Yzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E1CAx2/S6cCZdkGCevEsXCS+0
yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep+OkuE6N36B9K
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFujCCA6KgAwIBAgIJALtAHEP1Xk+wMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNVBAYTAkNI
MRUwEwYDVQQKEwxTd2lzc1NpZ24gQUcxHzAdBgNVBAMTFlN3aXNzU2lnbiBHb2xkIENBIC0g
RzIwHhcNMDYxMDI1MDgzMDM1WhcNMzYxMDI1MDgzMDM1WjBFMQswCQYDVQQGEwJDSDEVMBMG
A1UEChMMU3dpc3NTaWduIEFHMR8wHQYDVQQDExZTd2lzc1NpZ24gR29sZCBDQSAtIEcyMIIC
IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAr+TufoskDhJuqVAtFkQ7kpJcyrhdhJJC
Eyq8ZVeCQD5XJM1QiyUqt2/876LQwB8CJEoTlo8jE+YoWACjR8cGp4QjK7u9lit/VcyLwVcf
DmJlD909Vopz2q5+bbqBHH5CjCA12UNNhPqE21Is8w4ndwtrvxEvcnifLtg+5hg3Wipy+dpi
kJKVyh+c6bM8K8vzARO/Ws/BtQpgvd21mWRTuKCWs2/iJneRjOBiEAKfNA+k1ZIzUd6+jbqE
emA8atufK+ze3gE/bk3lUIbLtK/tREDFylqM2tIrfKjuvqblCqoOpd8FUrdVxyJdMmqXl2MT
28nbeTZ7hTpKxVKJ+STnnXepgv9VHKVxaSvRAiTysybUa9oEVeXBCsdtMDeQKuSeFDNeFhdV
xVu1yzSJkvGdJo+hB9TGsnhQ2wwMC3wLjEHXuendjIj3o02yMszYF9rNt85mndT9Xv+9lz4p
ded+p2JYryU0pUHHPbwNUMoDAw8IWh+Vc3hiv69yFGkOpeUDDniOJihC8AcLYiAQZzlG+qkD
zAQ4embvIIO1jEpWjpEA/I5cgt6IoMPiaG59je883WX0XaxR7ySArqpWl2/5rX3aYT+Ydzyl
kbYcjCbaZaIJbcHiVOO5ykxMgI93e2CaHt+28kgeDrpOVG2Y4OGiGqJ3UM/EY5LsRxmd6+Zr
zsECAwEAAaOBrDCBqTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQUWyV7lqRlUX64OfPAeGZe6Drn8O4wHwYDVR0jBBgwFoAUWyV7lqRlUX64OfPAeGZe6Drn
8O4wRgYDVR0gBD8wPTA7BglghXQBWQECAQEwLjAsBggrBgEFBQcCARYgaHR0cDovL3JlcG9z
aXRvcnkuc3dpc3NzaWduLmNvbS8wDQYJKoZIhvcNAQEFBQADggIBACe645R88a7A3hfm5djV
9VSwg/S7zV4Fe0+fdWavPOhWfvxyeDgD2StiGwC5+OlgzczOUYrHUDFu4Up+GC9pWbY9ZIEr
44OE5iKHjn3g7gKZYbge9LgriBIWhMIxkziWMaa5O1M/wySTVltpkuzFwbs4AOPsF6m43Md8
AYOfMke6UiI0HTJ6CVanfCU2qT1L2sCCbwq7EsiHSycR+R4tx5M/nttfJmtS2S6K8RTGRI0V
qbe/vd6mGu6uLftIdxf+u+yvGPUqUfA5hJeVbG4bwyvEdGB5JbAKJ9/fXtI5z0V9Qkvfsywe
xcZdylU6oJxpmo/a77KwPJ+HbBIrZXAVUjEaJM9vMSNQH4xPjyPDdEFjHFWoFN0+4FFQz/Eb
MFYOkrCChdiDyyJkvC24JdVUorgG6q2SpCSgwYa1ShNqR88uC1aVVMvOmttqtKay20EIhid3
92qgQmwLOM7XdVAyksLfKzAiSNDVQTglXaTpXZ/GlHXQRf0wl0OPkKsKx4ZzYEppLd6leNcG
2mqeSz53OiATIgHQv2ieY2BrNU0LbbqhPcCT4H8js1WtciVORvnSFu+wZMEBnunKoGqYDs/Y
YPIvSbjkQuE4NRb0yG5P94FW6LqjviOvrv1vA+ACOzB2+httQc8Bsem4yWb02ybzOqR08kkk
W8mw0FfB+j564ZfJ
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFvTCCA6WgAwIBAgIITxvUL1S7L0swDQYJKoZIhvcNAQEFBQAwRzELMAkGA1UEBhMCQ0gx
FTATBgNVBAoTDFN3aXNzU2lnbiBBRzEhMB8GA1UEAxMYU3dpc3NTaWduIFNpbHZlciBDQSAt
IEcyMB4XDTA2MTAyNTA4MzI0NloXDTM2MTAyNTA4MzI0NlowRzELMAkGA1UEBhMCQ0gxFTAT
BgNVBAoTDFN3aXNzU2lnbiBBRzEhMB8GA1UEAxMYU3dpc3NTaWduIFNpbHZlciBDQSAtIEcy
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxPGHf9N4Mfc4yfjDmUO8x/e8N+dO
cbpLj6VzHVxumK4DV644N0MvFz0fyM5oEMF4rhkDKxD6LHmD9ui5aLlV8gREpzn5/ASLHvGi
TSf5YXu6t+WiE7brYT7QbNHm+/pe7R20nqA1W6GSy/BJkv6FCgU+5tkL4k+73JU3/JHpMjUi
0R86TieFnbAVlDLaYQ1HTWBCrpJH6INaUFjpiou5XaHc3ZlKHzZnu0jkg7Y360g6rw9njxcH
6ATK72oxh9TAtvmUcXtnZLi2kUpCe2UuMGoM9ZDulebyzYLs2aFK7PayS+VFheZteJMELpyC
bTapxDFkH4aDCyr0NQp4yVXPQbBH6TCfmb5hqAaEuSh6XzjZG6k4sIN/c8HDO0gqgg8hm7jM
qDXDhBuDsz6+pJVpATqJAHgE2cn0mRmrVn5bi4Y5FZGkECwJMoBgs5PAKrYYC51+jUnyEEp/
+dVGLxmSo5mnJqy7jDzmDrxHB9xzUfFwZC8I+bRHHTBsROopN4WSaGa8gzj+ezku01DwH/te
YLappvonQfGbGHLy9YR0SslnxFSuSGTfjNFusB3hB48IHpmccelM2KX3RxIfdNFRnobzwqIj
QAtz20um53MGjMGg6cFZrEb65i/4z3GcRm25xBWNOHkDRUjvxF3XCO6HOSKGsg0PWEP3calI
Lv3q1h8CAwEAAaOBrDCBqTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNV
HQ4EFgQUF6DNweRBtjpbO8tFnb0cwpj6hlgwHwYDVR0jBBgwFoAUF6DNweRBtjpbO8tFnb0c
wpj6hlgwRgYDVR0gBD8wPTA7BglghXQBWQEDAQEwLjAsBggrBgEFBQcCARYgaHR0cDovL3Jl
cG9zaXRvcnkuc3dpc3NzaWduLmNvbS8wDQYJKoZIhvcNAQEFBQADggIBAHPGgeAn0i0P4JUw
4ppBf1AsX19iYamGamkYDHRJ1l2E6kFSGG9YrVBWIGrGvShpWJHckRE1qTodvBqlYJ7YH39F
kWnZfrt4csEGDyrOj4VwYaygzQu4OSlWhDJOhrs9xCrZ1x9y7v5RoSJBsXECYxqCsGKrXlcS
H9/L3XWgwF15kIwb4FDm3jH+mHtwX6WQ2K34ArZv02DdQEsixT2tOnqfGhpHkXkzuoLcMmkD
lm4fS/Bx/uNncqCxv1yL5PqZIseEuRuNI5c/7SXgz2W79WEE790eslpBIlqhn10s6FvJbakM
DHiqYMZWjwFaDGi8aRl5xB9+lwW/xekkUV7U1UtT7dkjWjYDZaPBA61BMPNGG4WQr2W11bHk
Flt4dR2Xem1ZqSqPe97Dh4kQmUlzeMg9vVE1dCrV8X5pGyq7O70luJpaPXJhkGaH7gzWTdQR
dAtq/gsD/KNVV4n+SsuuWxcFyPKNIzFTONItaj+CuY0IavdeQXRuwxF+B6wpYJE/OMpXEA29
MC/HpeZBoNquBYeaoKRlbEwJDIm6uNO5wJOKMPqN5ZprFQFOZ6raYlY+hAhm0sQ2fac+EPyI
4NSA5QC9qvNOBqN6avlicuMJT+ubDgEj8Z+7fNzcbBGXJbLytGMU0gYqZ4yD9c7qB9iaah7s
5Aq7KkzrCWA5zspi2C5u
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIDuDCCAqCgAwIBAgIQDPCOXAgWpa1Cf/DrJxhZ0DANBgkqhkiG9w0BAQUFADBIMQswCQYD
VQQGEwJVUzEgMB4GA1UEChMXU2VjdXJlVHJ1c3QgQ29ycG9yYXRpb24xFzAVBgNVBAMTDlNl
Y3VyZVRydXN0IENBMB4XDTA2MTEwNzE5MzExOFoXDTI5MTIzMTE5NDA1NVowSDELMAkGA1UE
BhMCVVMxIDAeBgNVBAoTF1NlY3VyZVRydXN0IENvcnBvcmF0aW9uMRcwFQYDVQQDEw5TZWN1
cmVUcnVzdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKukgeWVzfX2FI7C
T8rU4niVWJxB4Q2ZQCQXOZEzZum+4YOvYlyJ0fwkW2Gz4BERQRwdbvC4u/jep4G6pkjGnx29
vo6pQT64lO0pGtSO0gMdA+9tDWccV9cGrcrI9f4Or2YlSASWC12juhbDCE/RRvgUXPLIXgGZ
bf2IzIaowW8xQmxSPmjL8xk037uHGFaAJsTQ3MBv396gwpEWoGQRS0S8Hvbn+mPeZqx2pHGj
7DaUaHp3pLHnDi+BeuK1cobvomuL8A/b01k/unK8RCSc43Oz969XL0Imnal0ugBS8kvNU3xH
CzaFDmapCJcWNFfBZveA4+1wVMeT4C4oFVmHursCAwEAAaOBnTCBmjATBgkrBgEEAYI3FAIE
Bh4EAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUQjK2FvoE
/f5dS3rD/fdMQB1aQ68wNAYDVR0fBC0wKzApoCegJYYjaHR0cDovL2NybC5zZWN1cmV0cnVz
dC5jb20vU1RDQS5jcmwwEAYJKwYBBAGCNxUBBAMCAQAwDQYJKoZIhvcNAQEFBQADggEBADDt
T0rhWDpSclu1pqNlGKa7UTt36Z3q059c4EVlew3KW+JwULKUBRSuSceNQQcSc5R+DCMh/bwQ
f2AQWnL1mA6s7Ll/3XpvXdMc9P+IBWlCqQVxyLesJugutIxq/3HcuLHfmbx8IVQr5Fiiu1cp
rp6poxkmD5kuCLDv/WnPmRoJjeOnnyvJNjR7JLN4TJUXpAYmHrZkUjZfYGfZnMUFdAvnZyPS
CPyI6a6Lf+Ew9Dd+/cYy2i2eRDAwbO4H3tI0/NL/QPZL9GZGBlSm8jIKYyYwa5vR3ItHuuG5
1WLQoqD0ZwV4KWMabwTW+MZMo5qxN7SN5ShLHZ4swrhovO0C7jE=
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIDvDCCAqSgAwIBAgIQB1YipOjUiolN9BPI8PjqpTANBgkqhkiG9w0BAQUFADBKMQswCQYD
VQQGEwJVUzEgMB4GA1UEChMXU2VjdXJlVHJ1c3QgQ29ycG9yYXRpb24xGTAXBgNVBAMTEFNl
Y3VyZSBHbG9iYWwgQ0EwHhcNMDYxMTA3MTk0MjI4WhcNMjkxMjMxMTk1MjA2WjBKMQswCQYD
VQQGEwJVUzEgMB4GA1UEChMXU2VjdXJlVHJ1c3QgQ29ycG9yYXRpb24xGTAXBgNVBAMTEFNl
Y3VyZSBHbG9iYWwgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvNS7YrGxV
aQZx5RNoJLNP2MwhR/jxYDiJiQPpvepeRlMJ3Fz1Wuj3RSoC6zFh1ykzTM7HfAo3fg+6Mpjh
HZevj8fcyTiW89sa/FHtaMbQbqR8JNGuQsiWUGMu4P51/pinX0kuleM5M2SOHqRfkNJnPLLZ
/kG5VacJjnIFHovdRIWCQtBJwB1g8NEXLJXr9qXBkqPFwqcIYA1gBBCWeZ4WNOaptvolRTnI
HmX5k/Wq8VLcmZg9pYYaDDUz+kulBAYVHDGA76oYa8J719rO+TMg1fW9ajMtgQT7sFzUnKPi
XB3jqUJ1XnvUd+85VLrJChgbEplJL4hL/VBi0XPnj3pDAgMBAAGjgZ0wgZowEwYJKwYBBAGC
NxQCBAYeBABDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFK9E
BMJBfkiD2045AuzshHrmzsmkMDQGA1UdHwQtMCswKaAnoCWGI2h0dHA6Ly9jcmwuc2VjdXJl
dHJ1c3QuY29tL1NHQ0EuY3JsMBAGCSsGAQQBgjcVAQQDAgEAMA0GCSqGSIb3DQEBBQUAA4IB
AQBjGghAfaReUw132HquHw0LURYD7xh8yOOvaliTFGCRsoTciE6+OYo68+aCiV0BN7OrJKQV
DpI1WkpEXk5X+nXOH0jOZvQ8QCaSmGwb7iRGDBezUqXbpZGRzzfTb+cnCDpOGR86p1hcF895
P4vkp9MmI50mD1hp/Ed+stCNi5O/KU9DaXR2Z0vPB4zmAve14bRDtUstFJ/53CYNv6ZHdAbY
iNE6KTCEztI5gGIbqMdXSbxqVVFnFUq+NQfk1XWYN3kwFNspnWzFacxHVaIw98xcf8LDmBxr
ThaA63p4ZUWiABqvDA1VZDRIuJK58bRQKfJPIx/abKwfROHdI3hRW8cW
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIEHTCCAwWgAwIBAgIQToEtioJl4AsC7j41AkblPTANBgkqhkiG9w0BAQUFADCBgTELMAkG
A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9y
ZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxJzAlBgNVBAMTHkNPTU9ETyBDZXJ0aWZp
Y2F0aW9uIEF1dGhvcml0eTAeFw0wNjEyMDEwMDAwMDBaFw0yOTEyMzEyMzU5NTlaMIGBMQsw
CQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxm
b3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEnMCUGA1UEAxMeQ09NT0RPIENlcnRp
ZmljYXRpb24gQXV0aG9yaXR5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0ECL
i3LjkRv3UcEbVASY06m/weaKXTuH+7uIzg3jLz8GlvCiKVCZrts7oVewdFFxze1CkU1B/qnI
2GqGd0S7WWaXUF601CxwRM/aN5VCaTwwxHGzUvAhTaHYujl8HJ6jJJ3ygxaYqhZ8Q5sVW7eu
NJH+1GImGEaaP+vB+fGQV+useg2L23IwambV4EajcNxo2f8ESIl33rXp+2dtQem8Ob0y2WIC
8bGoPW43nOIv4tOiJovGuFVDiOEjPqXSJDlqR6sA1KGzqSX+DT+nHbrTUcELpNqsOO9VUCQF
ZUaTNE8tja3G1CEZ0o7KBWFxB3NH5YoZEr0ETc5OnKVIrLsm9wIDAQABo4GOMIGLMB0GA1Ud
DgQWBBQLWOWLxkwVN6RAqTCpIb5HNlpW/zAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9DT01PRE9D
ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDANBgkqhkiG9w0BAQUFAAOCAQEAPpiem/Yb6dc5
t3iuHXIYSdOH5EOC6z/JqvWote9VfCFSZfnVDeFs9D6Mk3ORLgLETgdxb8CPOGEIqB6BCsAv
IC9Bi5HcSEW88cbeunZrM8gALTFGTO3nnc+IlP8zwFboJIYmuNg4ON8qa90SzMc/RxdMosIG
lgnW2/4/PEZB31jiVg88O8EckzXZOFKs7sjsLjBOlDW0JB9LeGna8gI4zJVSk/BwJVmcIGfE
7vmLV2H0knZ9P4SNVbfo5azV8fUZVqZa+5Acr5Pr5RzUZ5ddBA6+C4OmF4O5MBKgxTMVBbkN
+8cFduPYSo38NBejxiEovjBFMR7HeL5YYTisO+IBZQ==
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIICiTCCAg+gAwIBAgIQH0evqmIAcFBUTAGem2OZKjAKBggqhkjOPQQDAzCBhTELMAkGA1UE
BhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEa
MBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBFQ0MgQ2VydGlm
aWNhdGlvbiBBdXRob3JpdHkwHhcNMDgwMzA2MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCBhTEL
MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2Fs
Zm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBFQ0Mg
Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQDR3svdcmC
FYX7deSRFtSrYpn1PlILBs5BAH+X4QokPB0BBO490o0JlwzgdeT6+3eKKvUDYEs2ixYjFq0J
cfRK9ChQtP6IHG4/bC8vCVlbpVsLM5niwz2J+Wos77LTBumjQjBAMB0GA1UdDgQWBBR1cacZ
SBm8nZ3qQUfflMRId5nTeTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggq
hkjOPQQDAwNoADBlAjEA7wNbeqy3eApyt4jf/7VGFAkK+qDmfQjGGoe9GKhzvSbKYAydzpmf
z1wPMOG+FDHqAjAU9JM8SaczepBGR7NjfRObTrdvGDeAU/7dIOA1mjbRxwG55tzd8/8dLDoW
V9mSOdY=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIDqDCCApCgAwIBAgIJAP7c4wEPyUj/MA0GCSqGSIb3DQEBBQUAMDQxCzAJBgNVBAYTAkZS
MRIwEAYDVQQKDAlEaGlteW90aXMxETAPBgNVBAMMCENlcnRpZ25hMB4XDTA3MDYyOTE1MTMw
NVoXDTI3MDYyOTE1MTMwNVowNDELMAkGA1UEBhMCRlIxEjAQBgNVBAoMCURoaW15b3RpczER
MA8GA1UEAwwIQ2VydGlnbmEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDIaPHJ
1tazNHUmgh7stL7qXOEm7RFHYeGifBZ4QCHkYJ5ayGPhxLGWkv8YbWkj4Sti993iNi+RB7lI
zw7sebYs5zRLcAglozyHGxnygQcPOJAZ0xH+hrTy0V4eHpbNgGzOOzGTtvKg0KmVEn2lmsxr
yIRWijOp5yIVUxbwzBfsV1/pogqYCd7jX5xv3EjjhQsVWqa6n6xI4wmy9/Qy3l40vhx4XUJb
zg4ij02Q130yGLMLLGq/jj8UEYkgDncUtT2UCIf3JR7VsmAA7G8qKCVuKj4YYxclPz5EIBb2
JsglrgVKtOdjLPOMFlN+XPsRGgjBRmKfIrjxwo1p3Po6WAbfAgMBAAGjgbwwgbkwDwYDVR0T
AQH/BAUwAwEB/zAdBgNVHQ4EFgQUGu3+QTmQtCRZvgHyUtVF9lo53BEwZAYDVR0jBF0wW4AU
Gu3+QTmQtCRZvgHyUtVF9lo53BGhOKQ2MDQxCzAJBgNVBAYTAkZSMRIwEAYDVQQKDAlEaGlt
eW90aXMxETAPBgNVBAMMCENlcnRpZ25hggkA/tzjAQ/JSP8wDgYDVR0PAQH/BAQDAgEGMBEG
CWCGSAGG+EIBAQQEAwIABzANBgkqhkiG9w0BAQUFAAOCAQEAhQMeknH2Qq/ho2Ge6/PAD/Kl
1NqV5ta+aDY9fm4fTIrv0Q8hbV6lUmPOEvjvKtpv6zf+EwLHyzs+ImvaYS5/1HI93TDhHkxA
GYwP15zRgzB7mFncfca5DClMoTOi62c6ZYTTluLtdkVwj7Ur3vkj1kluPBS1xp81HlDQwY9q
cEQCYsuuHWhBp6pX6FOqB9IG9tUUBguRA3UsbHK1YZWaDYu5Def131TN3ubY1gkIl2PlwS6w
t0QmwCbAr1UwnjvVNioZBPRcHv/PLLf/0P2HQBHVESO7SMAhqaQoLf0V+LBOK/QwWyH8EZE0
vkHve52Xdf+XlcCWWC/qu0bXu+TZLg==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFsDCCA5igAwIBAgIQFci9ZUdcr7iXAF7kBtK8nTANBgkqhkiG9w0BAQUFADBeMQswCQYD
VQQGEwJUVzEjMCEGA1UECgwaQ2h1bmdod2EgVGVsZWNvbSBDby4sIEx0ZC4xKjAoBgNVBAsM
IWVQS0kgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0wNDEyMjAwMjMxMjdaFw0z
NDEyMjAwMjMxMjdaMF4xCzAJBgNVBAYTAlRXMSMwIQYDVQQKDBpDaHVuZ2h3YSBUZWxlY29t
IENvLiwgTHRkLjEqMCgGA1UECwwhZVBLSSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA4SUP7o3biDN1Z82tH306Tm2d0y8U
82N0ywEhajfqhFAHSyZbCUNsIZ5qyNUD9WBpj8zwIuQf5/dqIjG3LBXy4P4AakP/h2XGtRrB
p0xtInAhijHyl3SJCRImHJ7K2RKilTza6We/CKBk49ZCt0Xvl/T29de1ShUCWH2YWEtgvM3X
DZoTM1PRYfl61dd4s5oz9wCGzh1NlDivqOx4UXCKXBCDUSH3ET00hl7lSM2XgYI1TBnsZfZr
xQWh7kcT1rMhJ5QQCtkkO7q+RBNGMD+XPNjX12ruOzjjK9SXDrkb5wdJfzcq+Xd4z1TtW0ad
o4AOkUPB1ltfFLqfpo0kR0BZv3I4sjZsN/+Z0V0OWQqraffAsgRFelQArr5T9rXn4fg8ozHS
qf4hUmTFpmfwdQcGlBSBVcYn5AGPF8Fqcde+S/uUWH1+ETOxQvdibBjWzwloPn9s9h6PYq2l
Y9sJpx8iQkEeb5mKPtf5P0B6ebClAZLSnT0IFaUQAS2zMnaolQ2zepr7BxB4EW/hj8e6DyUa
dCrlHJhBmd8hh+iVBmoKs2pHdmX2Os+PYhcZewoozRrSgx4hxyy/vv9haLdnG7t4TY3OZ+Xk
wY63I2binZB1NJipNiuKmpS5nezMirH4JYlcWrYvjB9teSSnUmjDhDXiZo1jDiVN1Rmy5nk3
pyKdVDECAwEAAaNqMGgwHQYDVR0OBBYEFB4M97Zn8uGSJglFwFU5Lnc/QkqiMAwGA1UdEwQF
MAMBAf8wOQYEZyoHAAQxMC8wLQIBADAJBgUrDgMCGgUAMAcGBWcqAwAABBRFsMLHClZ87lt4
DJX5GFPBphzYEDANBgkqhkiG9w0BAQUFAAOCAgEACbODU1kBPpVJufGBuvl2ICO1J2B01GqZ
NF5sAFPZn/KmsSQHRGoqxqWOeBLoR9lYGxMqXnmbnwoqZ6YlPwZpVnPDimZI+ymBV3QGypzq
KOg4ZyYr8dW1P2WT+DZdjo2NQCCHGervJ8A9tDkPJXtoUHRVnAxZfVo9QZQlUgjgRywVMRnV
vwdVxrsStZf0X4OFunHB2WyBEXYKCrC/gpf36j36+uwtqSiUO1bd0lEursC9CBWMd1I0ltab
rNMdjmEPNXubrjlpC2JgQCA2j6/7Nu4tCEoduL+bXPjqpRugc6bY+G7gMwRfaKonh+3ZwZCc
7b3jajWvY9+rGNm65ulK6lCKD2GTHuItGeIwlDWSXQ62B68ZgI9HkFFLLk3dheLSClIKF5r8
GrBQAuUBo2M3IUxExJtRmREOc5wGj1QupyheRDmHVi03vYVElOEMSyycw5KFNGHLD7ibSkNS
/jQ6fbjpKdx2qcgw+BRxgMYeNkh0IkFch4LoGHGLQYlE535YW6i4jRPpp2zDR+2zGp1iro2C
6pSe3VkQw63d4k3jMdXH7OjysP6SHhYKGvzZ8/gntsm+HbRsZJB/9OTEW9c3rkIO3aQab3yI
VMUWbuF6aC74Or8NpDyJO3inTmODBCEIZ43ygknQW/2xzQ+DhNQ+IIX3Sj0rnP0qCglN6oH4
EZw=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIDODCCAiCgAwIBAgIGIAYFFnACMA0GCSqGSIb3DQEBBQUAMDsxCzAJBgNVBAYTAlJPMREw
DwYDVQQKEwhjZXJ0U0lHTjEZMBcGA1UECxMQY2VydFNJR04gUk9PVCBDQTAeFw0wNjA3MDQx
NzIwMDRaFw0zMTA3MDQxNzIwMDRaMDsxCzAJBgNVBAYTAlJPMREwDwYDVQQKEwhjZXJ0U0lH
TjEZMBcGA1UECxMQY2VydFNJR04gUk9PVCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBALczuX7IJUqOtdu0KBuqV5Do0SLTZLrTk+jUrIZhQGpgV2hUhE28alQCBf/fm5oq
rl0Hj0rDKH/v+yv6efHHrfAQUySQi2bJqIirr1qjAOm+ukbuW3N7LBeCgV5iLKECZbO9xSsA
fsT8AzNXDe3i+s5dRdY4zTW2ssHQnIFKquSyAVwdj1+ZxLGt24gh65AIgoDzMKND5pCCrlUo
Se1b16kQOA7+j0xbm0bqQfWwCHTD0IgztnzXdN/chNFDDnU5oSVAKOp4yw4sLjmdjItuFhwv
JoIQ4uNllAoEwF73XVv4EOLQunpL+943AAAaWyjj0pxzPjKHmKHJUS/X3qwzs08CAwEAAaNC
MEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAcYwHQYDVR0OBBYEFOCMm9slSbPx
fIbWskKHC9BroNnkMA0GCSqGSIb3DQEBBQUAA4IBAQA+0hyJLjX8+HXd5n9liPRyTMks1zJO
890ZeUe9jjtbkw9QSSQTaxQGcu8J06Gh40CEyecYMnQ8SG4Pn0vU9x7Tk4ZkVJdjclDVVc/6
IJMCopvDI5NOFlV2oHB5bc0hH88vLbwZ44gx+FkagQnIl6Z0x2DEW8xXjrJ1/RsCCdtZb3KT
afcxQdaIOL+Hsr0Wefmq5L6IJd1hJyMctTEHBDa0GpC9oHRxUIltvBTjD4au8as+x6AJzKNI
0eDbZOeStc+vckNwi/nDhDwTqn6Sm1dTk/pwwpEOMfmbZ13pljheX7NzTogVZ96edhBiIL5V
aZVDADlN9u6wWk5JRFRYX0KD
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIEFTCCAv2gAwIBAgIGSUEs5AAQMA0GCSqGSIb3DQEBCwUAMIGnMQswCQYDVQQGEwJIVTER
MA8GA1UEBwwIQnVkYXBlc3QxFTATBgNVBAoMDE5ldExvY2sgS2Z0LjE3MDUGA1UECwwuVGFu
w7pzw610dsOhbnlraWFkw7NrIChDZXJ0aWZpY2F0aW9uIFNlcnZpY2VzKTE1MDMGA1UEAwws
TmV0TG9jayBBcmFueSAoQ2xhc3MgR29sZCkgRsWRdGFuw7pzw610dsOhbnkwHhcNMDgxMjEx
MTUwODIxWhcNMjgxMjA2MTUwODIxWjCBpzELMAkGA1UEBhMCSFUxETAPBgNVBAcMCEJ1ZGFw
ZXN0MRUwEwYDVQQKDAxOZXRMb2NrIEtmdC4xNzA1BgNVBAsMLlRhbsO6c8OtdHbDoW55a2lh
ZMOzayAoQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcykxNTAzBgNVBAMMLE5ldExvY2sgQXJhbnkg
KENsYXNzIEdvbGQpIEbFkXRhbsO6c8OtdHbDoW55MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEAxCRec75LbRTDofTjl5Bu0jBFHjzuZ9lk4BqKf8owyoPjIMHj9DrTlF8afFtt
vzBPhCf2nx9JvMaZCpDyD/V/Q4Q3Y1GLeqVw/HpYzY6b7cNGbIRwXdrzAZAj/E4wqX7hJ2Pn
7WQ8oLjJM2P+FpD/sLj916jAwJRDC7bVWaaeVtAkH3B5r9s5VA1lddkVQZQBr17s9o3x/61k
/iCa11zr/qYfCGSji3ZVrR47KGAuhyXoqq8fxmRGILdwfzzeSNuWU7c5d+Qa4scWhHaXWy+7
GRWF+GmF9ZmnqfI0p6m2pgP8b4Y9VHx2BJtr+UBdADTHLpl1neWIA6pN+APSQnbAGwIDAKiL
o0UwQzASBgNVHRMBAf8ECDAGAQH/AgEEMA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUzPpn
k/C2uNClwB7zU/2MU9+D15YwDQYJKoZIhvcNAQELBQADggEBAKt/7hwWqZw8UQCgwBEIBaeZ
5m8BiFRhbvG5GK1Krf6BQCOUL/t1fC8oS2IkgYIL9WHxHG64YTjrgfpioTtaYtOUZcTh5m2C
+C8lcLIhJsFyUR+MLMOEkMNaj7rP9KdlpeuY0fsFskZ1FSNqb4VjMIDw1Z4fKRzCbLBQWV2Q
WzuoDTDPv31/zvGdg73JRm4gpvlhUbohL3u+pRVjodSVh/GeufOJ8z2FuLjbvrW5KfnaNwUA
SZQDhETnv0Mxz3WLJdH0pmT1kvarBes96aULNmLazAZfNou2XjG4Kvte9nHfRCaexOYNkbQu
dZWAUWpLMKawYqGT8ZvYzsRjdT9ZR7E=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIDbTCCAlWgAwIBAgIBATANBgkqhkiG9w0BAQUFADBYMQswCQYDVQQGEwJKUDErMCkGA1UE
ChMiSmFwYW4gQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcywgSW5jLjEcMBoGA1UEAxMTU2VjdXJl
U2lnbiBSb290Q0ExMTAeFw0wOTA0MDgwNDU2NDdaFw0yOTA0MDgwNDU2NDdaMFgxCzAJBgNV
BAYTAkpQMSswKQYDVQQKEyJKYXBhbiBDZXJ0aWZpY2F0aW9uIFNlcnZpY2VzLCBJbmMuMRww
GgYDVQQDExNTZWN1cmVTaWduIFJvb3RDQTExMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEA/XeqpRyQBTvLTJszi1oURaTnkBbR31fSIRCkF/3frNYfp+TbfPfs37gD2pRY/V1y
fIw/XwFndBWW4wI8h9uuywGOwvNmxoVF9ALGOrVisq/6nL+k5tSAMJjzDbaTj6nU2DbysPyK
yiyhFTOVMdrAG/LuYpmGYz+/3ZMqg6h2uRMft85OQoWPIucuGvKVCbIFtUROd6EgvanyTgp9
UK31BQ1FT0Zx/Sg+U/sE2C3XZR1KG/rPO7AxmjVuyIsG0wCR8pQIZUyxNAYAeoni8McDWc/V
1uinMrPmmECGxc0nEovMe863ETxiYAcjPitAbpSACW22s293bzUIUPsCh8U+iQIDAQABo0Iw
QDAdBgNVHQ4EFgQUW/hNT7KlhtQ60vFjmqC+CfZXt94wDgYDVR0PAQH/BAQDAgEGMA8GA1Ud
EwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAKChOBZmLqdWHyGcBvod7bkixTgm2E5P
7KN/ed5GIaGHd48HCJqypMWvDzKYC3xmKbabfSVSSUOrTC4rbnpwrxYO4wJs+0LmGJ1F2FXI
6Dvd5+H0LgscNFxsWEr7jIhQX5Ucv+2rIrVls4W6ng+4reV6G4pQOh29Dbx7VFALuUKvVaAY
ga1lme++5Jy/xIWrQbJUb9wlze144o4MjQlJ3WN7WmmWAiGovVJZ6X01y8hSyn+B/tlr0/cR
7SXf+Of5pPpyl4RTDaXQMhhRdlkUbA/r7F+AjHVDg8OFmP9Mni0N5HeDk061lgeLKBObjBmN
QSdJQO7e5iNEOdyhIta6A/I=
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIECjCCAvKgAwIBAgIJAMJ+QwRORz8ZMA0GCSqGSIb3DQEBCwUAMIGCMQswCQYDVQQGEwJI
VTERMA8GA1UEBwwIQnVkYXBlc3QxFjAUBgNVBAoMDU1pY3Jvc2VjIEx0ZC4xJzAlBgNVBAMM
Hk1pY3Jvc2VjIGUtU3ppZ25vIFJvb3QgQ0EgMjAwOTEfMB0GCSqGSIb3DQEJARYQaW5mb0Bl
LXN6aWduby5odTAeFw0wOTA2MTYxMTMwMThaFw0yOTEyMzAxMTMwMThaMIGCMQswCQYDVQQG
EwJIVTERMA8GA1UEBwwIQnVkYXBlc3QxFjAUBgNVBAoMDU1pY3Jvc2VjIEx0ZC4xJzAlBgNV
BAMMHk1pY3Jvc2VjIGUtU3ppZ25vIFJvb3QgQ0EgMjAwOTEfMB0GCSqGSIb3DQEJARYQaW5m
b0BlLXN6aWduby5odTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOn4j/NjrdqG
2KfgQvvPkd6mJviZpWNwrZuuyjNAfW2WbqEORO7hE52UQlKavXWFdCyoDh2Tthi3jCyoz/tc
cbna7P7ofo/kLx2yqHWH2Leh5TvPmUpG0IMZfcChEhyVbUr02MelTTMuhTlAdX4UfIASmFDH
QWe4oIBhVKZsTh/gnQ4H6cm6M+f+wFUoLAKApxn1ntxVUwOXewdI/5n7N4okxFnMUBBjjqqp
GrCEGob5X7uxUG6k0QrM1XF+H6cbfPVTbiJfyyvm1HxdrtbCxkzlBQHZ7Vf8wSN5/PrIJIOV
87VqUQHQd9bpEqH5GoP7ghu5sJf0dgYzQ0mg/wu1+rUCAwEAAaOBgDB+MA8GA1UdEwEB/wQF
MAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBTLD8bfQkPMPcu1SCOhGnqmKrs0aDAf
BgNVHSMEGDAWgBTLD8bfQkPMPcu1SCOhGnqmKrs0aDAbBgNVHREEFDASgRBpbmZvQGUtc3pp
Z25vLmh1MA0GCSqGSIb3DQEBCwUAA4IBAQDJ0Q5eLtXMs3w+y/w9/w0olZMEyL/azXm4Q5Dw
pL7v8u8hmLzU1F0G9u5C7DBsoKqpyvGvivo/C3NqPuouQH4frlRheesuCDfXI/OMn74dseGk
ddug4lQUsbocKaQY9hK6ohQU4zE1yED/t+AFdlfBHFny+L/k7SViXITwfn4fs775tyERzAMB
VnCnEJIeGzSBHq2cGsMEPO0CYdYeBvNfOofyK/FFh+U9rNHHV4S9a67c2Pm2G2JwCz02yULy
Mtd6YebS2z3PyKnJm9zbWETXbzivf3jTo60adbocwTZ8jx5tHMN1Rq41Bab2XD0h7lbwyYIi
LXpUq3DDfSJlgnCW
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIDXzCCAkegAwIBAgILBAAAAAABIVhTCKIwDQYJKoZIhvcNAQELBQAwTDEgMB4GA1UECxMX
R2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMT
Ckdsb2JhbFNpZ24wHhcNMDkwMzE4MTAwMDAwWhcNMjkwMzE4MTAwMDAwWjBMMSAwHgYDVQQL
ExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSMzETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UE
AxMKR2xvYmFsU2lnbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMwldpB5Bngi
FvXAg7aEyiie/QV2EcWtiHL8RgJDx7KKnQRfJMsuS+FggkbhUqsMgUdwbN1k0ev1LKMPgj0M
K66X17YUhhB5uzsTgHeMCOFJ0mpiLx9e+pZo34knlTifBtc+ycsmWQ1z3rDI6SYOgxXG71uL
0gRgykmmKPZpO/bLyCiR5Z2KYVc3rHQU3HTgOu5yLy6c+9C7v/U9AOEGM+iCK65TpjoWc4zd
QQ4gOsC0p6Hpsk+QLjJg6VfLuQSSaGjlOCZgdbKfd/+RFO+uIEn8rUAVSNECMWEZXriX7613
t2Saer9fwRPvm2L7DWzgVGkWqQPabumDk3F2xmmFghcCAwEAAaNCMEAwDgYDVR0PAQH/BAQD
AgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFI/wS3+oLkUkrk1Q+mOai97i3Ru8MA0G
CSqGSIb3DQEBCwUAA4IBAQBLQNvAUKr+yAzv95ZURUm7lgAJQayzE4aGKAczymvmdLm6AC2u
pArT9fHxD4q/c2dKg8dEe3jgr25sbwMpjjM5RcOO5LlXbKr8EpbsU8Yt5CRsuZRj+9xTaGdW
PoO4zzUhw8lo/s7awlOqzJCK6fBdRoyV3XpYKBovHd7NADdBj+1EbddTKJd+82cEHhXXipa0
095MJ6RMG3NzdvQXmcIfeg7jLQitChws/zyrVQ4PkX4268NXSb7hLi18YIvDQVETI53O9zJr
lAGomecsMx86OyXShkDOOyyGeMlhLxS67ttVb9+E7gUJTb0o2HLO02JQZR7rkpeDMdmztcpH
WD9f
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIF8TCCA9mgAwIBAgIQALC3WhZIX7/hy/WL1xnmfTANBgkqhkiG9w0BAQsFADA4MQswCQYD
VQQGEwJFUzEUMBIGA1UECgwLSVpFTlBFIFMuQS4xEzARBgNVBAMMCkl6ZW5wZS5jb20wHhcN
MDcxMjEzMTMwODI4WhcNMzcxMjEzMDgyNzI1WjA4MQswCQYDVQQGEwJFUzEUMBIGA1UECgwL
SVpFTlBFIFMuQS4xEzARBgNVBAMMCkl6ZW5wZS5jb20wggIiMA0GCSqGSIb3DQEBAQUAA4IC
DwAwggIKAoICAQDJ03rKDx6sp4boFmVqscIbRTJxldn+EFvMr+eleQGPicPK8lVx93e+d5Tz
cqQsRNiekpsUOqHnJJAKClaOxdgmlOHZSOEtPtoKct2jmRXagaKH9HtuJneJWK3W6wyyQXpz
bm3benhB6QiIEn6HLmYRY2xU+zydcsC8Lv/Ct90NduM61/e0aL6i9eOBbsFGb12N4E3GVFWJ
GjMxCrFXuaOKmMPsOzTFlUFpfnXCPCDFYbpRR6AgkJOhkEvzTnyFRVSa0QUmQbC1TR0zvsQD
yCV8wXDbO/QJLVQnSKwv4cSsPsjLkkxTOTcj7NMB+eAJRE1NZMDhDVqHIrytG6P+JrUV86f8
hBnp7KGItERphIPzidF0BqnMC9bC3ieFUCbKF7jJeodWLBoBHmy+E60QrLUk9TiRodZL2vG7
0t5HtfG8gfZZa88ZU+mNFctKy6lvROUbQc/hhqfK0GqfvEyNBjNaooXlkDWgYlwWTvDjovoD
GrQscbNYLN57C9saD+veIR8GdwYDsMnvmfzAuU8Lhij+0rnq49qlw0dpEuDb8PYZi+17cNcC
1u2HGCgsBCRMd+RIihrGO5rUD8r6ddIBQFqNeb+Lz0vPqhbBleStTIo+F5HUsWLlguWABKQD
fo2/2n+iD5dPDNMN+9fR5XJ+HMh3/1uaD7euBUbl8agW7EekFwIDAQABo4H2MIHzMIGwBgNV
HREEgagwgaWBD2luZm9AaXplbnBlLmNvbaSBkTCBjjFHMEUGA1UECgw+SVpFTlBFIFMuQS4g
LSBDSUYgQTAxMzM3MjYwLVJNZXJjLlZpdG9yaWEtR2FzdGVpeiBUMTA1NSBGNjIgUzgxQzBB
BgNVBAkMOkF2ZGEgZGVsIE1lZGl0ZXJyYW5lbyBFdG9yYmlkZWEgMTQgLSAwMTAxMCBWaXRv
cmlhLUdhc3RlaXowDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE
FB0cZQ6o8iV7tJHP5LGx5r1VdGwFMA0GCSqGSIb3DQEBCwUAA4ICAQB4pgwWSp9MiDrAyw6l
Fn2fuUhfGI8NYjb2zRlrrKvV9pF9rnHzP7MOeIWblaQnIUdCSnxIOvVFfLMMjlF4rJUT3sb9
fbgakEyrkgPH7UIBzg/YsfqikuFgba56awmqxinuaElnMIAkejEWOVt+8Rwu3WwJrfIxwYJO
ubv5vr8qhT/AQKM6WfxZSzwoJNu0FXWuDYi6LnPAvViH5ULy617uHjAimcs30cQhbIHsvm0m
5hzkQiCeR7Csg1lwLDXWrzY0tM07+DKo7+N4ifuNRSzanLh+QBxh5z6ikixL8s36mLYp//Py
e6kfLqCTVyvehQP5aTfLnnhqBbTFMXiJ7HqnheG5ezzevh55hM6fcA5ZwjUukCox2eRFekGk
LhObNA5me0mrZJfQRsN5nXJQY6aYWwa9SG3YOYNw6DXwBdGqvOPbyALqfP2C2sJbUjWumDqt
ujWTI6cfSN01RpiyEGjkpTHCClguGYEQyVB1/OpaFs4R1+7vUIgtYf8/QnMFlEPVjjxOAToZ
pR9GTnfQXeWBIiGH/pR9hNiTrdZoQ0iy2+tzJOeRf1SktoA+naM8THLCV8Sg1Mw4J87VBp6i
SNnpn86CcDaTmjvfliHjWbcM2pE38P1ZWrOZyGlsQyYBNWNgVYkDOnXYukrZVP/u3oDYLdE4
1V4tC5h9Pmzb/CaIxw==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMxEDAOBgNV
BAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoTEUdvRGFkZHkuY29t
LCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAt
IEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIzNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAw
DgYDVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5
LmNvbSwgSW5jLjExMC8GA1UEAxMoR28gRGFkZHkgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
dHkgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9xYgjx+lk09xvJGKP3
gElY6SKDE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpPL1kwIuerGVZr4oAH
/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7RnwyDfMAZiLI
jWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVhGkSBjCypQ5Yj36w6
gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGRtDtwKj9useiciAF9n9T521Nt
YJ2/LOdYq7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAO
BgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3
DQEBCwUAA4IBAQCZ21151fmXWWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC
2gV7+AJ1uP2lsdeu9tfeE8tTEH6KRtGX+rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95
kTXWXwTrgIOrmgIttRD02JDHBHNA7XIloKmf7J6raBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo
2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPKf1855eJ1usV2GDPOLPAvTK33
sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI4uJEvlz36hz1
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIID3TCCAsWgAwIBAgIBADANBgkqhkiG9w0BAQsFADCBjzELMAkGA1UEBhMCVVMxEDAOBgNV
BAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxJTAjBgNVBAoTHFN0YXJmaWVsZCBU
ZWNobm9sb2dpZXMsIEluYy4xMjAwBgNVBAMTKVN0YXJmaWVsZCBSb290IENlcnRpZmljYXRl
IEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIzNTk1OVowgY8xCzAJ
BgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMSUwIwYD
VQQKExxTdGFyZmllbGQgVGVjaG5vbG9naWVzLCBJbmMuMTIwMAYDVQQDEylTdGFyZmllbGQg
Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAL3twQP89o/8ArFvW59I2Z154qK3A2FWGMNHttfKPTUuiUP3oWmb3ooa/RMg
nLRJdzIpVv257IzdIvpy3Cdhl+72WoTsbhm5iSzchFvVdPtrX8WJpRBSiUZV9Lh1HOZ/5FSu
S/hVclcCGfgXcVnrHigHdMWdSL5stPSksPNkN3mSwOxGXn/hbVNMYq/NHwtjuzqd+/x5AJhh
dM8mgkBj87JyahkNmcrUDnXMN/uLicFZ8WJ/X7NfZTD4p7dNdloedl40wOiWVpmKs/B/pM29
3DIxfJHP4F8R+GuqSVzRmZTRouNjWwl2tVZi4Ut0HZbUJtQIBFnQmA4O5t78w+wfkPECAwEA
AaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFHwMMh+n
2TB/xH1oo2Kooc6rB1snMA0GCSqGSIb3DQEBCwUAA4IBAQARWfolTwNvlJk7mh+ChTnUdgWU
XuEok21iXQnCoKjUsHU48TRqneSfioYmUeYs0cYtbpUgSpIB7LiKZ3sx4mcujJUDJi5DnUox
9g61DLu34jd/IroAow57UvtruzvE03lRTs2Q9GcHGcg8RnoNAX3FWOdt5oUwF5okxBDgBPfg
8n/Uqgr/Qh037ZTlZFkSIHc40zI+OIF1lnP6aI+xy84fxez6nH7PfrHxBy22/L/KpL/QlwVK
vOoYKAKQvVR4CSFx09F9HdkWsKlhPdAKACL8x3vLCWRFCztAgfd9fDL1mMpYjn0q7pBZc2T5
NnReJaH1ZgUufzkVqSr7UIuOhWn0
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIID7zCCAtegAwIBAgIBADANBgkqhkiG9w0BAQsFADCBmDELMAkGA1UEBhMCVVMxEDAOBgNV
BAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxJTAjBgNVBAoTHFN0YXJmaWVsZCBU
ZWNobm9sb2dpZXMsIEluYy4xOzA5BgNVBAMTMlN0YXJmaWVsZCBTZXJ2aWNlcyBSb290IENl
cnRpZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAwMFoXDTM3MTIzMTIzNTk1
OVowgZgxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNk
YWxlMSUwIwYDVQQKExxTdGFyZmllbGQgVGVjaG5vbG9naWVzLCBJbmMuMTswOQYDVQQDEzJT
dGFyZmllbGQgU2VydmljZXMgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIw
DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANUMOsQq+U7i9b4Zl1+OiFOxHz/Lz58gE20p
OsgPfTz3a3Y4Y9k2YKibXlwAgLIvWX/2h/klQ4bnaRtSmpDhcePYLQ1Ob/bISdm28xpWriu2
dBTrz/sm4xq6HZYuajtYlIlHVv8loJNwU4PahHQUw2eeBGg6345AWh1KTs9DkTvnVtYAcMtS
7nt9rjrnvDH5RfbCYM8TWQIrgMw0R9+53pBlbQLPLJGmpufehRhJfGZOozptqbXuNC66DQO4
M99H67FrjSXZm86B0UVGMpZwh94CDklDhbZsc7tk6mFBrMnUVN+HL8cisibMn1lUaJ/8viov
xFUcdUBgF4UCVTmLfwUCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
AQYwHQYDVR0OBBYEFJxfAN+qAdcwKziIorhtSpzyEZGDMA0GCSqGSIb3DQEBCwUAA4IBAQBL
NqaEd2ndOxmfZyMIbw5hyf2E3F/YNoHN2BtBLZ9g3ccaaNnRbobhiCPPE95Dz+I0swSdHynV
v/heyNXBve6SbzJ08pGCL72CQnqtKrcgfU28elUSwhXqvfdqlS5sdJ/PHLTyxQGjhdByPq1z
qwubdQxtRbeOlKyWN7Wg0I8VRw7j6IPdj/3vQQF3zCepYoUz8jcI73HPdwbeyBkdiEDPfUYd
/x7H4c7/I9vG+o1VTqkC50cRRj70/b17KSa7qWFiNyi2LSr2EIZkyXCn0q23KXB56jzaYyWf
/Wi3MOxw+3WKt21gZ7IeyLnp2KhvAotnDU0mV3HaIPzBSlCNsSi6
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIDTDCCAjSgAwIBAgIId3cGJyapsXwwDQYJKoZIhvcNAQELBQAwRDELMAkGA1UEBhMCVVMx
FDASBgNVBAoMC0FmZmlybVRydXN0MR8wHQYDVQQDDBZBZmZpcm1UcnVzdCBDb21tZXJjaWFs
MB4XDTEwMDEyOTE0MDYwNloXDTMwMTIzMTE0MDYwNlowRDELMAkGA1UEBhMCVVMxFDASBgNV
BAoMC0FmZmlybVRydXN0MR8wHQYDVQQDDBZBZmZpcm1UcnVzdCBDb21tZXJjaWFsMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9htPZwcroRX1BiLLHwGy43NFBkRJLLtJJRTW
zsO3qyxPxkEylFf6EqdbDuKPHx6GGaeqtS25Xw2Kwq+FNXkyLbscYjfysVtKPcrNcV/pQr6U
6Mje+SJIZMblq8Yrba0F8PrVC8+a5fBQpIs7R6UjW3p6+DM/uO+Zl+MgwdYoic+U+7lF7eNA
FxHUdPALMeIrJmqbTFeurCA+ukV6BfO9m2kVrn1OIGPENXY6BwLJN/3HR+7o8XYdcxXyl6S1
yHp52UKqK39c/s4mT6NmgTWvRLpUHhwwMmWd5jyTXlBOeuM61G7MGvv50jeuJCqrVwMiKA1J
dX+3KNp1v47j3A55MQIDAQABo0IwQDAdBgNVHQ4EFgQUnZPGU4teyq8/nx4P5ZmVvCT2lI8w
DwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAFis
9AQOzcAN/wr91LoWXym9e2iZWEnStB03TX8nfUYGXUPGhi4+c7ImfU+TqbbEKpqrIZcUsd6M
06uJFdhrJNTxFq7YpFzUf1GO7RgBsZNjvbz4YYCanrHOQnDiqX0GJX0nof5v7LMeJNrjS1Ua
ADs1tDvZ110w/YETifLCBivtZ8SOyUOyXGsViQK8YvxO8rUzqrJv0wqiUOP2O+guRMLbZjip
M1ZI8W0bM40NjD9gN53Tym1+NH4Nn3J2ixufcv1SNUFFApYvHLKac0khsUlHRUe072o0EclN
msxZt9YCnlpOZbWUrhvfKbAW8b8Angc6F2S1BLUjIZkKlTuXfO8=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIDTDCCAjSgAwIBAgIIfE8EORzUmS0wDQYJKoZIhvcNAQEFBQAwRDELMAkGA1UEBhMCVVMx
FDASBgNVBAoMC0FmZmlybVRydXN0MR8wHQYDVQQDDBZBZmZpcm1UcnVzdCBOZXR3b3JraW5n
MB4XDTEwMDEyOTE0MDgyNFoXDTMwMTIzMTE0MDgyNFowRDELMAkGA1UEBhMCVVMxFDASBgNV
BAoMC0FmZmlybVRydXN0MR8wHQYDVQQDDBZBZmZpcm1UcnVzdCBOZXR3b3JraW5nMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtITMMxcua5Rsa2FSoOujz3mUTOWUgJnLVWRE
ZY9nZOIG41w3SfYvm4SEHi3yYJ0wTsyEheIszx6e/jarM3c1RNg1lho9Nuh6DtjVR6FqaYvZ
/Ls6rnla1fTWcbuakCNrmreIdIcMHl+5ni36q1Mr3Lt2PpNMCAiMHqIjHNRqrSK6mQEubWXL
viRmVSRLQESxG9fhwoXA3hA/Pe24/PHxI1Pcv2WXb9n5QHGNfb2V1M6+oF4nI979ptAmDgAp
6zxG8D1gvz9Q0twmQVGeFDdCBKNwV6gbh+0t+nvujArjqWaJGctB+d1ENmHP4ndGyH329JKB
Nv3bNPFyfvMMFr20FQIDAQABo0IwQDAdBgNVHQ4EFgQUBx/S55zawm6iQLSwelAQUHTEyL0w
DwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQEFBQADggEBAIlX
shZ6qML91tmbmzTCnLQyFE2npN/svqe++EPbkTfOtDIuUFUaNU52Q3Eg75N3ThVwLofDwR1t
3Mu1J9QsVtFSUzpE0nPIxBsFZVpikpzuQY0x2+c06lkh1QF612S4ZDnNye2v7UsDSKegmQGA
3GWjNq5lWUhPgkvIZfFXHeVZLgo/bNjR9eUJtGxUAArgFU2HdW23WJZa3W3SAKD0m0i+wzek
ujbgfIeFlxoVot4uolu9rxj5kFDNcFn4J2dHy8egBzp90SxdbBk6ZrV9/ZFvgrG+CJPbFEfx
ojfHRZ48x3evZKiT3/Zpg4Jg8klCNO1aAFSFHBY2kgxc+qatv9s=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFRjCCAy6gAwIBAgIIbYwURrGmCu4wDQYJKoZIhvcNAQEMBQAwQTELMAkGA1UEBhMCVVMx
FDASBgNVBAoMC0FmZmlybVRydXN0MRwwGgYDVQQDDBNBZmZpcm1UcnVzdCBQcmVtaXVtMB4X
DTEwMDEyOTE0MTAzNloXDTQwMTIzMTE0MTAzNlowQTELMAkGA1UEBhMCVVMxFDASBgNVBAoM
C0FmZmlybVRydXN0MRwwGgYDVQQDDBNBZmZpcm1UcnVzdCBQcmVtaXVtMIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxBLfqV/+Qd3d9Z+K4/as4Tx4mrzY8H96oDMq3I0gW64t
b+eT2TZwamjPjlGjhVtnBKAQJG9dKILBl1fYSCkTtuG+kU3fhQxTGJoeJKJPj/CihQvL9Cl/
0qRY7iZNyaqoe5rZ+jjeRFcV5fiMyNlI4g0WJx0eyIOFJbe6qlVBzAMiSy2RjYvmia9mx+n/
K+k8rNrSs8PhaJyJ+HoAVt70VZVs+7pk3WKL3wt3MutizCaam7uqYoNMtAZ6MMgpv+0GTZe5
HMQxK9VfvFMSF5yZVylmd2EhMQcuJUmdGPLu8ytxjLW6OQdJd/zvLpKQBY0tL3d770O/Nbua
2Plzpyzy0FfuKE4mX4+QaAkvuPjcBukumj5Rp9EixAqnOEhss/n/fauGV+O61oV4d7pD6kh/
9ti+I20ev9E2bFhc8e6kGVQa9QPSdubhjL08s9NIS+LI+H+SqHZGnEJlPqQewQcDWkYtuJfz
t9WyVSHvutxMAJf7FJUnM7/oQ0dG0giZFmA7mn7S5u046uwBHjxIVkkJx0w3AJ6IDsBz4W9m
6XJHMD4Q5QsDyZpCAGzFlH5hxIrff4IaC1nEWTJ3s7xgaVY5/bQGeyzWZDbZvUjthB9+pSKP
KrhC9IK31FOQeE4tGv2Bb0TXOwF0lkLgAOIua+rF7nKsu7/+6qqo+Nz2snmKtmcCAwEAAaNC
MEAwHQYDVR0OBBYEFJ3AZ6YMItkm9UWrpmVSESfYRaxjMA8GA1UdEwEB/wQFMAMBAf8wDgYD
VR0PAQH/BAQDAgEGMA0GCSqGSIb3DQEBDAUAA4ICAQCzV00QYk465KzquByvMiPIs0laUZx2
KI15qldGF9X1Uva3ROgIRL8YhNILgM3FEv0AVQVhh0HctSSePMTYyPtwni94loMgNt58D2kT
iKV1NpgIpsbfrM7jWNa3Pt668+s0QNiigfV4Py/VpfzZotReBA4Xrf5B8OWycvpEgjNC6C1Y
91aMYj+6QrCcDFx+LmUmXFNPALJ4fqENmS2NuB2OosSw/WDQMKSOyARiqcTtNd56l+0OOF6S
L5Nwpamcb6d9Ex1+xghIsV5n61EIJenmJWtSKZGc0jlzCFfemQa0W50QBuHCAKi4HEoCChTQ
wUHK+4w1IX2COPKpVJEZNZOUbWo6xbLQu4mGk+ibyQ86p3q4ofB4Rvr8Ny/lioTz3/4E2aFo
oC8k4gmVBtWVyuEklut89pMFu+1z6S3RdTnX5yTb2E5fQ4+e0BQ5v1VwSJlXMbSc7kqYA5Yw
H2AG7hsj/oFgIxpHYoWlzBk0gG+zrBrjn/B7SK3VAdlntqlyk+otZrWyuOQ9PLLvTIzq6we/
qzWaVYa8GKa1qF60g2xraUDTn9zxw2lrueFtCfTxqlB2Cnp9ehehVZZCmTEJ3WARjQUwfuaO
RtGdFNrHF+QFlozEJLUbzxQHskD4o55BhrwE0GuWyCqANP2/7waj3VjFhT0+j/6eKeC2uAlo
GRwYQw==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIB/jCCAYWgAwIBAgIIdJclisc/elQwCgYIKoZIzj0EAwMwRTELMAkGA1UEBhMCVVMxFDAS
BgNVBAoMC0FmZmlybVRydXN0MSAwHgYDVQQDDBdBZmZpcm1UcnVzdCBQcmVtaXVtIEVDQzAe
Fw0xMDAxMjkxNDIwMjRaFw00MDEyMzExNDIwMjRaMEUxCzAJBgNVBAYTAlVTMRQwEgYDVQQK
DAtBZmZpcm1UcnVzdDEgMB4GA1UEAwwXQWZmaXJtVHJ1c3QgUHJlbWl1bSBFQ0MwdjAQBgcq
hkjOPQIBBgUrgQQAIgNiAAQNMF4bFZ0D0KF5Nbc6PJJ6yhUczWLznCZcBz3lVPqj1swS6vQU
X+iOGasvLkjmrBhDeKzQN8O9ss0s5kfiGuZjuD0uL3jET9v0D6RoTFVya5UdThhClXjMNzyR
4ptlKymjQjBAMB0GA1UdDgQWBBSaryl6wBE1NSZRMADDav5A1a7WPDAPBgNVHRMBAf8EBTAD
AQH/MA4GA1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNnADBkAjAXCfOHiFBar8jAQr9HX/Vs
aobgxCd05DhT1wV/GzTjxi+zygk8N53X57hG8f2h4nECMEJZh0PUUd+60wkyWs6Iflc9nF9C
a/UHLbXwgpP5WW+uZPpY5Yse42O+tYHNbwKMeQ==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDuzCCAqOgAwIBAgIDBETAMA0GCSqGSIb3DQEBBQUAMH4xCzAJBgNVBAYTAlBMMSIwIAYD
VQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlm
aWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0Ew
HhcNMDgxMDIyMTIwNzM3WhcNMjkxMjMxMTIwNzM3WjB+MQswCQYDVQQGEwJQTDEiMCAGA1UE
ChMZVW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRpZmlj
YXRpb24gQXV0aG9yaXR5MSIwIAYDVQQDExlDZXJ0dW0gVHJ1c3RlZCBOZXR3b3JrIENBMIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4/t9o3K6wvDJFIf1awFO4W5AB7ptJ11/
91sts1rHUV+rpDKmYYe2bg+G0jACl/jXaVehGDldamR5xgFZrDwxSjh80gTSSyjoIF87B6LM
TXPb865Px1bVWqeWifrzq2jUI4ZZJ88JJ7ysbnKDHDBy3+Ci6dLhdHUZvSqeexVUBBvXQzmt
VSjF4hq79MDkrjhJM8x2hZ85RdKknvISjFH4fOQtf/WsX+sWn7Et0brMkUJ3TCXJkDhv2/DM
+44el1k+1WBO5gUo7Ul5E0u6SNsv+XLTOcr+H9g0cvW0QM8xAcPs3hEtF10fuFDRXhmnad4H
MyjKUJX5p1TLVIZQRan5SQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQI
ds3LB/8k9sXN7buQvOKEN0Z19zAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQEFBQADggEB
AKaorSLOAT2mo/9i0Eidi15ysHhE49wcrwn9I0j6vSrEuVUEtRCjjSfeC4Jj0O7eDDd5QVsi
srCaQVymcODU0HfLI9MA4GxWL+FpDQ3Zqr8hgVDZBqWo/5U30Kr+4rP1mS1FhIrlQgnXdAIv
94nYmem8J9RHjboNRhx3zxSkHLmkMcScKHQDNP8zGSal6Q10tz6XxnboJ5ajZt3hrvJBW8qY
VoNzcOSGGtIxQbovvi0TWnZvTuhOgQ4/WwMioBK+ZlgRSssDxLQqKi2WF+A5VLxI03YnnZot
BqbJ7DnSq9ufmgsnAjUpsUCV5/nonFWIGUbWtzT1fs45mtk48VH3Tyw=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDezCCAmOgAwIBAgIBATANBgkqhkiG9w0BAQUFADBfMQswCQYDVQQGEwJUVzESMBAGA1UE
CgwJVEFJV0FOLUNBMRAwDgYDVQQLDAdSb290IENBMSowKAYDVQQDDCFUV0NBIFJvb3QgQ2Vy
dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMDgwODI4MDcyNDMzWhcNMzAxMjMxMTU1OTU5WjBf
MQswCQYDVQQGEwJUVzESMBAGA1UECgwJVEFJV0FOLUNBMRAwDgYDVQQLDAdSb290IENBMSow
KAYDVQQDDCFUV0NBIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQCwfnK4pAOU5qfeCTiRShFAh6d8WWQUe7UREN3+v9XAu1bi
hSX0NXIP+FPQQeFEAcK0HMMxQhZHhTMidrIKbw/lJVBPhYa+v5guEGcevhEFhgWQxFnQfHgQ
sIBct+HHK3XLfJ+utdGdIzdjp9xCoi2SBBtQwXu4PhvJVgSLL1KbralW6cH/ralYhzC2gfeX
RfwZVzsrb+RH9JlF/h3x+JejiB03HFyP4HYlmlD4oFT/RJB2I9IyxsOrBr/8+7/zrX2SYgJb
KdM1o5OaQ2RgXbL6Mv87BK9NQGr5x+PvI/1ry+UPizgN7gr8/g+YnzAx3WxSZfmLgb4i4RxY
A7qRG4kHAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1Ud
DgQWBBRqOFsmjd6LWvJPelSDGRjjCDWmujANBgkqhkiG9w0BAQUFAAOCAQEAPNV3PdrfibqH
DAhUaiBQkr6wQT25JmSDCi/oQMCXKCeCMErJk/9q56YAf4lCmtYR5VPOL8zy2gXE/uJQxDqG
fczafhAJO5I1KlOy/usrBdlsXebQ79NqZp4VKIV66IIArB6nCWlWQtNoURi+VJq/REG6Sb4g
umlc7rh3zc5sH62Dlhh9DrUUOYTxKOkto557HnpyWoOzeW/vtPzQCqVYT0bf+215WfKEIlKu
D8z7fDvnaspHYcN6+NOSBB+4IIThNlQWx0DeO4pz3N/GCUzf7Nr/1FNCocnyYh0igzyXxfkZ
YiesZSLX0zzG5Y6yU8xJzrww/nsOM5D77dIUkR8Hrw==
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIDdzCCAl+gAwIBAgIBADANBgkqhkiG9w0BAQsFADBdMQswCQYDVQQGEwJKUDElMCMGA1UE
ChMcU0VDT00gVHJ1c3QgU3lzdGVtcyBDTy4sTFRELjEnMCUGA1UECxMeU2VjdXJpdHkgQ29t
bXVuaWNhdGlvbiBSb290Q0EyMB4XDTA5MDUyOTA1MDAzOVoXDTI5MDUyOTA1MDAzOVowXTEL
MAkGA1UEBhMCSlAxJTAjBgNVBAoTHFNFQ09NIFRydXN0IFN5c3RlbXMgQ08uLExURC4xJzAl
BgNVBAsTHlNlY3VyaXR5IENvbW11bmljYXRpb24gUm9vdENBMjCCASIwDQYJKoZIhvcNAQEB
BQADggEPADCCAQoCggEBANAVOVKxUrO6xVmCxF1SrjpDZYBLx/KWvNs2l9amZIyoXvDjChz3
35c9S672XewhtUGrzbl+dp+++T42NKA7wfYxEUV0kz1XgMX5iZnK5atq1LXaQZAQwdbWQonC
v/Q4EpVMVAX3NuRFg3sUZdbcDE3R3n4MqzvEFb46VqZab3ZpUql6ucjrappdUtAtCms1FgkQ
hNBqyjoGADdH5H5XTz+L62e4iKrFvlNVspHEfbmwhRkGeC7bYRr6hfVKkaHnFtWOojnflLhw
Hyg/i/xAXmODPIMqGplrz95Zajv8bxbXH/1KEOtOghY6rCcMU/Gt1SSwawNQwS08Ft1ENCca
dfsCAwEAAaNCMEAwHQYDVR0OBBYEFAqFqXdlBZh8QIH4D5csOPEK7DzPMA4GA1UdDwEB/wQE
AwIBBjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQBMOqNErLlFsceTfsgL
CkLfZOoc7llsCLqJX2rKSpWeeo8HxdpFcoJxDjrSzG+ntKEju/Ykn8sX/oymzsLS28yN/HH8
AynBbF0zX2S2ZTuJbxh2ePXcokgfGT+Ok+vx+hfuzU7jBBJV1uXk3fs+BXziHV7Gp7yXT2g6
9ekuCkO2r1dcYmh8t/2jioSgrGK+KwmHNPBqAbubKVY8/gA3zyNs8U6qtnRGEmyR7jTV7JqR
50S+kDFy1UkC9gLl9B/rfNmWVan/7Ir5mUf/NVoCqgTLiluHcSmRvaS0eg29mvVXIwAHIRc/
SjnRBUkLp7Y3gaVdjKozXoEofKd9J+sAro03
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIFuzCCA6OgAwIBAgIIVwoRl0LE48wwDQYJKoZIhvcNAQELBQAwazELMAkGA1UEBhMCSVQx
DjAMBgNVBAcMBU1pbGFuMSMwIQYDVQQKDBpBY3RhbGlzIFMucC5BLi8wMzM1ODUyMDk2NzEn
MCUGA1UEAwweQWN0YWxpcyBBdXRoZW50aWNhdGlvbiBSb290IENBMB4XDTExMDkyMjExMjIw
MloXDTMwMDkyMjExMjIwMlowazELMAkGA1UEBhMCSVQxDjAMBgNVBAcMBU1pbGFuMSMwIQYD
VQQKDBpBY3RhbGlzIFMucC5BLi8wMzM1ODUyMDk2NzEnMCUGA1UEAwweQWN0YWxpcyBBdXRo
ZW50aWNhdGlvbiBSb290IENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAp8bE
pSmkLO/lGMWwUKNvUTufClrJwkg4CsIcoBh/kbWHuUA/3R1oHwiD1S0eiKD4j1aPbZkCkpAW
1V8IbInX4ay8IMKx4INRimlNAJZaby/ARH6jDuSRzVju3PvHHkVH3Se5CAGfpiEd9UEtL0z9
KK3giq0itFZljoZUj5NDKd45RnijMCO6zfB9E1fAXdKDa0hMxKufgFpbOr3JpyI/gCczWw63
igxdBzcIy2zSekciRDXFzMwujt0q7bd9Zg1fYVEiVRvjRuPjPdA1YprbrxTIW6HMiRvhMCb8
oJsfgadHHwTrozmSBp+Z07/T6k9QnBn+locePGX2oxgkg4YQ51Q+qDp2JE+BIcXjDwL4k5RH
ILv+1A7TaLndxHqEguNTVHnd25zS8gebLra8Pu2Fbe8lEfKXGkJh90qX6IuxEAf6ZYGyojnP
9zz/GPvG8VqLWeICrHuS0E4UT1lF9gxeKF+w6D9Fz8+vm2/7hNN3WpVvrJSEnu68wEqPSpP4
RCHiMUVhUE4Q2OM1fEwZtN4Fv6MGn8i1zeQf1xcGDXqVdFUNaBr8EBtiZJ1t4JWgw5QHVw0U
5r0F+7if5t+L4sbnfpb2U8WANFAoWPASUHEXMLrmeGO89LKtmyuy/uE5jF66CyCU3nuDuP/j
Vo23Eek7jPKxwV2dpAtMK9myGPW1n0sCAwEAAaNjMGEwHQYDVR0OBBYEFFLYiDrIn3hm7Ynz
ezhwlMkCAjbQMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUUtiIOsifeGbtifN7OHCU
yQICNtAwDgYDVR0PAQH/BAQDAgEGMA0GCSqGSIb3DQEBCwUAA4ICAQALe3KHwGCmSUyIWOYd
iPcUZEim2FgKDk8TNd81HdTtBjHIgT5q1d07GjLukD0R0i70jsNjLiNmsGe+b7bAEzlgqqI0
JZN1Ut6nna0Oh4lScWoWPBkdg/iaKWW+9D+a2fDzWochcYBNy+A4mz+7+uAwTc+G02UQGRjR
lwKxK3JCaKygvU5a2hi/a5iB0P2avl4VSM0RFbnAKVy06Ij3Pjaut2L9HmLecHgQHEhb2ryk
OLpn7VU+Xlff1ANATIGk0k9jpwlCCRT8AKnCgHNPLsBA2RF7SOp6AsDT6ygBJlh0wcBzIm2T
lf05fbsq4/aC4yyXX04fkZT6/iyj2HYauE2yOE+b+h1IYHkm4vP9qdCa6HCPSXrW5b0KDtst
842/6+OkfcvHlXHo2qN8xcL4dJIEG4aspCJTQLas/kx2z/uUMsA1n3Y/buWQbqCmJqK4LL7R
K4X9p2jIugErsWx0Hbhzlefut8cl8ABMALJ+tguLHPPAUJ4lueAI3jZm/zel0btUZCzJJ7VL
kn5l/9Mt4blOvH+kQSGQQXemOR/qnuOf0GZvBeyqdn6/axag67XH/JJULysRJyU3eExRarDz
zFhdFPFqSBX/wge2sY0PjlxQRrM9vwGYT7JZVEc+NHt4bVaTLnPqZih4zR0Uv6CPLy64Lo7y
FIrM6bV8+2ydDKXhlg==
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIFWTCCA0GgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBOMQswCQYDVQQGEwJOTzEdMBsGA1UE
CgwUQnV5cGFzcyBBUy05ODMxNjMzMjcxIDAeBgNVBAMMF0J1eXBhc3MgQ2xhc3MgMiBSb290
IENBMB4XDTEwMTAyNjA4MzgwM1oXDTQwMTAyNjA4MzgwM1owTjELMAkGA1UEBhMCTk8xHTAb
BgNVBAoMFEJ1eXBhc3MgQVMtOTgzMTYzMzI3MSAwHgYDVQQDDBdCdXlwYXNzIENsYXNzIDIg
Um9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANfHXvfBB9R3+0Mh9PT1
aeTuMgHbo4Yf5FkNuud1g1Lr6hxhFUi7HQfKjK6w3Jad6sNgkoaCKHOcVgb/S2TwDCo3SbXl
zwx87vFKu3MwZfPVL4O2fuPn9Z6rYPnT8Z2SdIrkHJasW4DptfQxh6NR/Md+oW+OU3fUl8FV
M5I+GC911K2GScuVr1QGbNgGE41b/+EmGVnAJLqBcXmQRFBoJJRfuLMR8SlBYaNByyM21cHx
MlAQTn/0hpPshNOOvEu/XAFOBz3cFIqUCqTqc/sLUegTBxj6DvEr0VQVfTzh97QZQmdiXnfg
olXsttlpF9U6r0TtSsWe5HonfOV116rLJeffawrbD02TTqigzXsu8lkBarcNuAeBfos4Gzjm
CleZPe4h6KP1DBbdi+w0jpwqHAAVF41og9JwnxgIzRFo1clrUs3ERo/ctfPYV3Me6ZQ5BL/T
3jjetFPsaRyifsSP5BtwrfKi+fv3FmRmaZ9JUaLiFRhnBkp/1Wy1TbMz4GHrXb7pmA8y1x1L
PC5aAVKRCfLf6o3YBkBjqhHk/sM3nhRSP/TizPJhk9H9Z2vXUq6/aKtAQ6BXNVN48FP4YUIH
ZMbXb5tMOA1jrGKvNouicwoN9SG9dKpN6nIDSdvHXx1iY8f93ZHsM+71bbRuMGjeyNYmsHVe
e7QHIJihdjK4TWxPAgMBAAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMmAd+Bi
koL1RpzzuvdMw964o605MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAU18h
9bqwOlI5LJKwbADJ784g7wbylp7ppHR/ehb8t/W2+xUbP6umwHJdELFx7rxP462sA20ucS6v
xOOto70MEae0/0qyexAQH6dXQbLArvQsWdZHEIjzIVEpMMpghq9Gqx3tOluwlN5E40EIosHs
Hdb9T7bWR9AUC8rmyrV7d35BH16Dx7aMOZawP5aBQW9gkOLo+fsicdl9sz1Gv7SEr5AcD48S
aq/v7h56rgJKihcrdv6sVIkkLE8/trKnToyokZf7KcZ7XC25y2a2t6hbElGFtQl+Ynhw/qlq
YLYdDnkM/crqJIByw5c/8nerQyIKx+u2DISCLIBrQYoIwOula9+ZEsuK1V6ADJHgJgg2SMX6
OBE1/yWDLfJ6v9r9jv6ly0UsH8SIU653DtmadsWOLB2jutXsMq7Aqqz30XpN69QH4kj3Io6w
pJ9qzo6ysmD0oyLQI+uUWnpp3Q+/QFesa1lQ2aOZ4W7+jQF5JyMV3pKdewlNWudLSDBaGOYK
beaP4NK75t98biGCwWg5TbSYWGZizEqQXsP6JwSxeRV0mcy+rSDeJmAc61ZRpqPq5KM/p/9h
3PFaTWwyI0PurKju7koSCTxdccK+efrCh2gdC/1cacwG0Jp9VJkqyTkaGa9LKkPzY11aWOIv
4x3kqdbQCtCev9eBCfHJxyYNrJgWVqA=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFWTCCA0GgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBOMQswCQYDVQQGEwJOTzEdMBsGA1UE
CgwUQnV5cGFzcyBBUy05ODMxNjMzMjcxIDAeBgNVBAMMF0J1eXBhc3MgQ2xhc3MgMyBSb290
IENBMB4XDTEwMTAyNjA4Mjg1OFoXDTQwMTAyNjA4Mjg1OFowTjELMAkGA1UEBhMCTk8xHTAb
BgNVBAoMFEJ1eXBhc3MgQVMtOTgzMTYzMzI3MSAwHgYDVQQDDBdCdXlwYXNzIENsYXNzIDMg
Um9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKXaCpUWUOOV8l6ddjEG
Mnqb8RB2uACatVI2zSRHsJ8YZLya9vrVediQYkwiL944PdbgqOkcLNt4EemOaFEVcsfzM4fk
oF0LXOBXByow9c3EN3coTRiR5r/VUv1xLXA+58bEiuPwKAv0dpihi4dVsjoT/Lc+JzeOIuOo
TyrvYLs9tznDDgFHmV0ST9tD+leh7fmdvhFHJlsTmKtdFoqwNxxXnUX/iJY2v7vKB3tvh2PX
0DJq1l1sDPGzbjniazEuOQAnFN44wOwZZoYS6J1yFhNkUsepNxz9gjDthBgd9K5c/3ATAOux
9TN6S9ZV+AWNS2mw9bMoNlwUxFFzTWsL8TQH2xc519woe2v1n/MuwU8XKhDzzMro6/1rqy6a
ny2CbgTUUgGTLT2G/H783+9CHaZr77kgxve9oKeV/afmiSTYzIw0bOIjL9kSGiG5VZFvC5F5
GQytQIgLcOJ60g7YaEi7ghM5EFjp2CoHxhLbWNvSO1UQRwUVZ2J+GGOmRj8JDlQyXr8NYnon
74Do29lLBlo3WiXQCBJ31G8JUJc9yB3D34xFMFbG02SrZvPAXpacw8Tvw3xrizp5f7NJzz3i
iZ+gMEuFuZyUJHmPfWupRWgPK9Dx2hzLabjKSWJtyNBjYt1gD1iqj6G8BaVmos8bdrKEZLFM
OVLAMLrwjEsCsLa3AgMBAAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFEe4zf/l
b+74suwvTg75JbCOPGvDMA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAACAj
QTUEkMJAYmDv4jVM1z+s4jSQuKFvdvoWFqRINyzpkMLyPPgKn9iB5btb2iUspKdVcSQy9sgL
8rxq+JOssgfCX5/bzMiKqr5qb+FJEMwx14C7u8jYog5kV+qi9cKpMRXSIGrs/CIBKM+GuIAe
qcwRpTzyFrNHnfzSgCHEy9BHcEGhyoMZCCxt8l13nIoUE9Q2HJLw5QY33KbmkJs4j1xrG0aG
Q0JfPgEHU1RdZX33inOhmlRaHylDFCfChQ+1iHsaO5S3HWCntZznKWlXWpuTekMwGwPXYshA
pqr8ZORK15FTAaggiG6cX0S5y2CBNOxv033aSF/rtJC8LakcC6wc1aJoIIAE1vyxjy+7SjEN
SoYc6+I2KSb12tjE8nVhz36udmNKekBlk4f4HoCMhuWG1o8O/FMsYOgWYRqiPkN7zTlgVGr1
8okmAWiDSKIz6MkEkbIRNBE+6tBDGR8Dk5AM/1E9V/RBbuHLoL7ryWPNbczk+DaqaJ3tvV2X
cEQNtg413OEMXbugUZTLfhbrES+jkkXITHHZvMmZUldGL1DPvTVp9D0VzgalLA8+9oG6lLvD
u79leNKGef9JOxqDDPDeeOzI8k1MGt6CKfjBWtrt7uYnXuhF0J0cUahoq0Tj0Itq4/g7u9xN
12TyUb7mqqta6THuBrxzvxNiCp/HuZc=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDwzCCAqugAwIBAgIBATANBgkqhkiG9w0BAQsFADCBgjELMAkGA1UEBhMCREUxKzApBgNV
BAoMIlQtU3lzdGVtcyBFbnRlcnByaXNlIFNlcnZpY2VzIEdtYkgxHzAdBgNVBAsMFlQtU3lz
dGVtcyBUcnVzdCBDZW50ZXIxJTAjBgNVBAMMHFQtVGVsZVNlYyBHbG9iYWxSb290IENsYXNz
IDMwHhcNMDgxMDAxMTAyOTU2WhcNMzMxMDAxMjM1OTU5WjCBgjELMAkGA1UEBhMCREUxKzAp
BgNVBAoMIlQtU3lzdGVtcyBFbnRlcnByaXNlIFNlcnZpY2VzIEdtYkgxHzAdBgNVBAsMFlQt
U3lzdGVtcyBUcnVzdCBDZW50ZXIxJTAjBgNVBAMMHFQtVGVsZVNlYyBHbG9iYWxSb290IENs
YXNzIDMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC9dZPwYiJvJK7genasfb3Z
JNW4t/zN8ELg63iIVl6bmlQdTQyK9tPPcPRStdiTBONGhnFBSivwKixVA9ZIw+A5OO3yXDw/
RLyTPWGrTs0NvvAgJ1gORH8EGoel15YUNpDQSXuhdfsaa3Ox+M6pCSzyU9XDFES4hqX2iys5
2qMzVNn6chr3IhUciJFrf2blw2qAsCTz34ZFiP0Zf3WHHx+xGwpzJFu5ZeAsVMhg02YXP+HM
VDNzkQI6pn97djmiH5a2OK61yJN0HZ65tOVgnS9W0eDrXltMEnAMbEQgqxHY9Bn20pxSN+f6
tsIxO0rUFJmtxxr1XV/6B7h8DR/Wgx6zAgMBAAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYD
VR0PAQH/BAQDAgEGMB0GA1UdDgQWBBS1A/d2O2GCahKqGFPrAyGUv/7OyjANBgkqhkiG9w0B
AQsFAAOCAQEAVj3vlNW92nOyWL6ukK2YJ5f+AbGwUgC4TeQbIXQbfsDuXmkqJa9c1h3a0nnJ
85cp4IaH3gRZD/FZ1GSFS5mvJQQeyUapl96Cshtwn5z2r3Ex3XsFpSzTucpH9sry9uetuUg/
vBa3wW306gmv7PO15wWeph6KU1HWk4HMdJP2udqmJQV0eVp+QD6CSyYRMG7hP0HHRwA11fXT
91Q+gT3aSWqas+8QPebrb9HIIkfLzM8BMZLZGOMivgkeGj5asuRrDFR6fUNOuImle9eiPZaG
zPImNC1qkp2aGtAw4l1OBLBfiyB+d8E9lYLRRpo7PHi4b6HQDWSieB4pTpPDpFQUWw==
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIEMzCCAxugAwIBAgIDCYPzMA0GCSqGSIb3DQEBCwUAME0xCzAJBgNVBAYTAkRFMRUwEwYD
VQQKDAxELVRydXN0IEdtYkgxJzAlBgNVBAMMHkQtVFJVU1QgUm9vdCBDbGFzcyAzIENBIDIg
MjAwOTAeFw0wOTExMDUwODM1NThaFw0yOTExMDUwODM1NThaME0xCzAJBgNVBAYTAkRFMRUw
EwYDVQQKDAxELVRydXN0IEdtYkgxJzAlBgNVBAMMHkQtVFJVU1QgUm9vdCBDbGFzcyAzIENB
IDIgMjAwOTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANOySs96R+91myP6Oi/W
UEWJNTrGa9v+2wBoqOADER03UAifTUpolDWzU9GUY6cgVq/eUXjsKj3zSEhQPgrfRlWLJ23D
EE0NkVJD2IfgXU42tSHKXzlABF9bfsyjxiupQB7ZNoTWSPOSHjRGICTBpFGOShrvUD9pXRl/
RcPHAY9RySPocq60vFYJfxLLHLGvKZAKyVXMD9O0Gu1HNVpK7ZxzBCHQqr0ME7UAyiZsxGsM
lFqVlNpQmvH/pStmMaTJOKDfHR+4CS7zp+hnUquVH+BGPtikw8paxTGA6Eian5Rp/hnd2HN8
gcqW3o7tszIFZYQ05ub9VxC1X3a/L7AQDcUCAwEAAaOCARowggEWMA8GA1UdEwEB/wQFMAMB
Af8wHQYDVR0OBBYEFP3aFMSfMN4hvR5COfyrYyNJ4PGEMA4GA1UdDwEB/wQEAwIBBjCB0wYD
VR0fBIHLMIHIMIGAoH6gfIZ6bGRhcDovL2RpcmVjdG9yeS5kLXRydXN0Lm5ldC9DTj1ELVRS
VVNUJTIwUm9vdCUyMENsYXNzJTIwMyUyMENBJTIwMiUyMDIwMDksTz1ELVRydXN0JTIwR21i
SCxDPURFP2NlcnRpZmljYXRlcmV2b2NhdGlvbmxpc3QwQ6BBoD+GPWh0dHA6Ly93d3cuZC10
cnVzdC5uZXQvY3JsL2QtdHJ1c3Rfcm9vdF9jbGFzc18zX2NhXzJfMjAwOS5jcmwwDQYJKoZI
hvcNAQELBQADggEBAH+X2zDI36ScfSF6gHDOFBJpiBSVYEQBrLLpME+bUMJm2H6NMLVwMeni
acfzcNsgFYbQDfC+rAF1hM5+n02/t2A7nPPKHeJeaNijnZflQGDSNiH+0LS4F9p0o3/U37CY
Aqxva2ssJSRyoWXuJVrl5jLn8t+rSfrzkGkj2wTZ51xY/GXUl77M/C4KzCUqNQT4YJEVdT1B
/yMfGchs64JTBKbkTCJNjYy6zltz7GRUUG3RnFX7acM2w4y8PIWmawomDeCTmGCufsYkl4ph
X5GOZpIJhzbNi5stPvZR1FDUWSi9g/LMKHtThm3YJohw1+qRzT65ysCQblrGXnRl11z+o+I=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIEQzCCAyugAwIBAgIDCYP0MA0GCSqGSIb3DQEBCwUAMFAxCzAJBgNVBAYTAkRFMRUwEwYD
VQQKDAxELVRydXN0IEdtYkgxKjAoBgNVBAMMIUQtVFJVU1QgUm9vdCBDbGFzcyAzIENBIDIg
RVYgMjAwOTAeFw0wOTExMDUwODUwNDZaFw0yOTExMDUwODUwNDZaMFAxCzAJBgNVBAYTAkRF
MRUwEwYDVQQKDAxELVRydXN0IEdtYkgxKjAoBgNVBAMMIUQtVFJVU1QgUm9vdCBDbGFzcyAz
IENBIDIgRVYgMjAwOTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJnxhDRwui+3
MKCOvXwEz75ivJn9gpfSegpnljgJ9hBOlSJzmY3aFS3nBfwZcyK3jpgAvDw9rKFs+9Z5JUut
8Mxk2og+KbgPCdM03TP1YtHhzRnp7hhPTFiu4h7WDFsVWtg6uMQYZB7jM7K1iXdODL/ZlGsT
l28So/6ZqQTMFexgaDbtCHu39b+T7WYxg4zGcTSHThfqr4uRjRxWQa4iN1438h3Z0S0NL2lR
p75mpoo6Kr3HGrHhFPC+Oh25z1uxav60sUYgovseO3Dvk5h9jHOW8sXvhXCtKSb8HgQ+HKDY
D8tSg2J87otTlZCpV6LqYQXY+U3EJ/pure3511H3a6UCAwEAAaOCASQwggEgMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFNOUikxiEyoZLsyvcop9NteaHNxnMA4GA1UdDwEB/wQEAwIB
BjCB3QYDVR0fBIHVMIHSMIGHoIGEoIGBhn9sZGFwOi8vZGlyZWN0b3J5LmQtdHJ1c3QubmV0
L0NOPUQtVFJVU1QlMjBSb290JTIwQ2xhc3MlMjAzJTIwQ0ElMjAyJTIwRVYlMjAyMDA5LE89
RC1UcnVzdCUyMEdtYkgsQz1ERT9jZXJ0aWZpY2F0ZXJldm9jYXRpb25saXN0MEagRKBChkBo
dHRwOi8vd3d3LmQtdHJ1c3QubmV0L2NybC9kLXRydXN0X3Jvb3RfY2xhc3NfM19jYV8yX2V2
XzIwMDkuY3JsMA0GCSqGSIb3DQEBCwUAA4IBAQA07XtaPKSUiO8aEXUHL7P+PPoeUSbrh/Yp
3uDx1MYkCenBz1UbtDDZzhr+BlGmFaQt77JLvyAoJUnRpjZ3NOhk31KxEcdzes05nsKtjHEh
8lprr988TlWvsoRlFIm5d8sqMb7Po23Pb0iUMkZv53GMoKaEGTcH8gNFCSuGdXzfX2lXANtu
2KZyIktQ1HWYVt+3GP9DQ1CuekR78HlR10M9p9OB0/DJT7naxpeG0ILD5EJt/rDiZE4OJudA
NCa1CInXCGNjOCd1HjPqbqjdn5lPdE2BiYBL3ZqXKVwvvoFBuYz/6n1gBp7N1z3TLqMVvKjm
JuVvw9y4AyHqnxbxLFS1
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIFaTCCA1GgAwIBAgIJAJK4iNuwisFjMA0GCSqGSIb3DQEBCwUAMFIxCzAJBgNVBAYTAlNL
MRMwEQYDVQQHEwpCcmF0aXNsYXZhMRMwEQYDVQQKEwpEaXNpZyBhLnMuMRkwFwYDVQQDExBD
QSBEaXNpZyBSb290IFIyMB4XDTEyMDcxOTA5MTUzMFoXDTQyMDcxOTA5MTUzMFowUjELMAkG
A1UEBhMCU0sxEzARBgNVBAcTCkJyYXRpc2xhdmExEzARBgNVBAoTCkRpc2lnIGEucy4xGTAX
BgNVBAMTEENBIERpc2lnIFJvb3QgUjIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
AQCio8QACdaFXS1tFPbCw3OeNcJxVX6B+6tGUODBfEl45qt5WDza/3wcn9iXAng+a0EE6UG9
vgMsRfYvZNSrXaNHPWSb6WiaxswbP7q+sos0Ai6YVRn8jG+qX9pMzk0DIaPY0jSTVpbLTAwA
FjxfGs3Ix2ymrdMxp7zo5eFm1tL7A7RBZckQrg4FY8aAamkw/dLukO8NJ9+flXP04SXabBbe
QTg06ov80egEFGEtQX6sx3dOy1FU+16SGBsEWmjGycT6txOgmLcRK7fWV8x8nhfRyyX+hk4k
LlYMeE2eARKmK6cBZW58Yh2EhN/qwGu1pSqVg8NTEQxzHQuyRpDRQjrOQG6Vrf/GlK1ul4SO
fW+eioANSW1z4nuSHsPzwfPrLgVv2RvPN3YEyLRa5Beny912H9AZdugsBbPWnDTYltxhh5EF
5EQIM8HauQhl1K6yNg3ruji6DOWbnuuNZt2Zz9aJQfYEkoopKW1rOhzndX0CcQ7zwOe9yxnd
nWCywmZgtrEE7snmhrmaZkCo5xHtgUUDi/ZnWejBBhG93c+AAk9lQHhcR1DIm+YfgXvkRKhb
hZri3lrVx/k6RGZL5DJUfORsnLMOPReisjQS1n6yqEm70XooQL6iFh/f5DcfEXP7kAplQ6IN
fPgGAVUzfbANuPT1rqVCV3w2EYx7XsQDnYx5nQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/
MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUtZn4r7CU9eMg1gqtzk5WpC5uQu0wDQYJKoZI
hvcNAQELBQADggIBACYGXnDnZTPIgm7ZnBc6G3pmsgH2eDtpXi/q/075KMOYKmFMtCQSin1t
ERT3nLXK5ryeJ45MGcipvXrA1zYObYVybqjGom32+nNjf7xueQgcnYqfGopTpti72TVVsRHF
qQOzVju5hJMiXn7B9hJSi+osZ7z+Nkz1uM/Rs0mSO9MpDpkblvdhuDvEK7Z4bLQjb/D907Je
dR+Zlais9trhxTF7+9FGs9K8Z7RiVLoJ92Owk6Ka+elSLotgEqv89WBW7xBci8QaQtyDW2QO
y7W81k/BfDxujRNt+3vrMNDcTa/F1balTFtxyegxvug4BkihGuLq0t4SOVga/4AOgnXmt8kH
bA7v/zjxmHHEt38OFdAlab0inSvtBfZGR6ztwPDUO+Ls7pZbkBNOHlY667DvlruWIxG68kOG
dGSVyCh13x01utI3gzhTODY7z2zp+WsO0PsE6E9312UBeIYMej4hYvF/Y3EMyZ9E26gnonW+
boE+18DrG5gPcFw0sorMwIUY6256s/daoQe/qUKS82Ail+QUoQebTnbAjn39pCXHR+3/H3Os
zMOl6W8KjptlwlCFtaOgUxLMVYdh84GuEEZhvUQhuMI9dM9+JDX6HAcOmz0iyu8xL4ysEr3v
QCj8KWefshNPZiTEUxnpHikV7+ZtsH8tZ/3zbBt1RqPlShfppNcL
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIH0zCCBbugAwIBAgIIXsO3pkN/pOAwDQYJKoZIhvcNAQEFBQAwQjESMBAGA1UEAwwJQUND
VlJBSVoxMRAwDgYDVQQLDAdQS0lBQ0NWMQ0wCwYDVQQKDARBQ0NWMQswCQYDVQQGEwJFUzAe
Fw0xMTA1MDUwOTM3MzdaFw0zMDEyMzEwOTM3MzdaMEIxEjAQBgNVBAMMCUFDQ1ZSQUlaMTEQ
MA4GA1UECwwHUEtJQUNDVjENMAsGA1UECgwEQUNDVjELMAkGA1UEBhMCRVMwggIiMA0GCSqG
SIb3DQEBAQUAA4ICDwAwggIKAoICAQCbqau/YUqXry+XZpp0X9DZlv3P4uRm7x8fRzPCRKPf
mt4ftVTdFXxpNRFvu8gMjmoYHtiP2Ra8EEg2XPBjs5BaXCQ316PWywlxufEBcoSwfdtNgM38
02/J+Nq2DoLSRYWoG2ioPej0RGy9ocLLA76MPhMAhN9KSMDjIgro6TenGEyxCQ0jVn8ETdkX
hBilyNpAlHPrzg5XPAOBOp0KoVdDaaxXbXmQeOW1tDvYvEyNKKGno6e6Ak4l0Squ7a4DIrhr
IA8wKFSVf+DuzgpmndFALW4ir50awQUZ0m/A8p/4e7MCQvtQqR0tkw8jq8bBD5L/0KIV9VMJ
cRz/RROE5iZe+OCIHAr8Fraocwa48GOEAqDGWuzndN9wrqODJerWx5eHk6fGioozl2A3ED6X
Pm4pFdahD9GILBKfb6qkxkLrQaLjlUPTAYVtjrs78yM2x/474KElB0iryYl0/wiPgL/AlmXz
7uxLaL2diMMxs0Dx6M/2OLuc5NF/1OVYm3z61PMOm3WR5LpSLhl+0fXNWhn8ugb2+1KoS5kE
3fj5tItQo05iifCHJPqDQsGH+tUtKSpacXpkatcnYGMN285J9Y0fkIkyF/hzQ7jSWpOGYdbh
dQrqeWZ2iE9x6wQl1gpaepPluUsXQA+xtrn13k/c4LOsOxFwYIRKQ26ZIMApcQrAZQIDAQAB
o4ICyzCCAscwfQYIKwYBBQUHAQEEcTBvMEwGCCsGAQUFBzAChkBodHRwOi8vd3d3LmFjY3Yu
ZXMvZmlsZWFkbWluL0FyY2hpdm9zL2NlcnRpZmljYWRvcy9yYWl6YWNjdjEuY3J0MB8GCCsG
AQUFBzABhhNodHRwOi8vb2NzcC5hY2N2LmVzMB0GA1UdDgQWBBTSh7Tj3zcnk1X2VuqB5TbM
jB4/vTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNKHtOPfNyeTVfZW6oHlNsyMHj+9
MIIBcwYDVR0gBIIBajCCAWYwggFiBgRVHSAAMIIBWDCCASIGCCsGAQUFBwICMIIBFB6CARAA
QQB1AHQAbwByAGkAZABhAGQAIABkAGUAIABDAGUAcgB0AGkAZgBpAGMAYQBjAGkA8wBuACAA
UgBhAO0AegAgAGQAZQAgAGwAYQAgAEEAQwBDAFYAIAAoAEEAZwBlAG4AYwBpAGEAIABkAGUA
IABUAGUAYwBuAG8AbABvAGcA7QBhACAAeQAgAEMAZQByAHQAaQBmAGkAYwBhAGMAaQDzAG4A
IABFAGwAZQBjAHQAcgDzAG4AaQBjAGEALAAgAEMASQBGACAAUQA0ADYAMAAxADEANQA2AEUA
KQAuACAAQwBQAFMAIABlAG4AIABoAHQAdABwADoALwAvAHcAdwB3AC4AYQBjAGMAdgAuAGUA
czAwBggrBgEFBQcCARYkaHR0cDovL3d3dy5hY2N2LmVzL2xlZ2lzbGFjaW9uX2MuaHRtMFUG
A1UdHwROMEwwSqBIoEaGRGh0dHA6Ly93d3cuYWNjdi5lcy9maWxlYWRtaW4vQXJjaGl2b3Mv
Y2VydGlmaWNhZG9zL3JhaXphY2N2MV9kZXIuY3JsMA4GA1UdDwEB/wQEAwIBBjAXBgNVHREE
EDAOgQxhY2N2QGFjY3YuZXMwDQYJKoZIhvcNAQEFBQADggIBAJcxAp/n/UNnSEQU5CmH7Uwo
ZtCPNdpNYbdKl02125DgBS4OxnnQ8pdpD70ER9m+27Up2pvZrqmZ1dM8MJP1jaGo/AaNRPTK
FpV8M9xii6g3+CfYCS0b78gUJyCpZET/LtZ1qmxNYEAZSUNUY9rizLpm5U9EelvZaoErQNV/
+QEnWCzI7UiRfD+mAM/EKXMRNt6GGT6d7hmKG9Ww7Y49nCrADdg9ZuM8Db3VlFzi4qc1GwQA
9j9ajepDvV+JHanBsMyZ4k0ACtrJJ1vnE5Bc5PUzolVt3OAJTS+xJlsndQAJxGJ3KQhfnlms
tn6tn1QwIgPBHnFk/vk4CpYY3QIUrCPLBhwepH2NDd4nQeit2hW3sCPdK6jT2iWH7ehVRE2I
9DZ+hJp4rPcOVkkO1jMl1oRQQmwgEh0q1b688nCBpHBgvgW1m54ERL5hI6zppSSMEYCUWqKi
uUnSwdzRp+0xESyeGabu4VXhwOrPDYTkF7eifKXeVSUG7szAh1xA2syVP1XgNce4hL60Xc16
gwFy7ofmXx2utYXGJt/mwZrpHgJHnyqobalbz+xFd3+YJ5oyXSrjhO7FmGYvliAd3djDJ9ew
+f7Zfc3Qn48LFFhRny+Lwzgt3uiP1o2HpPVWQxaZLPSkVrQ0uGE3ycJYgBugl6H8WY3pEfbR
D0tVNEYqi4Y7
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFQTCCAymgAwIBAgICDL4wDQYJKoZIhvcNAQELBQAwUTELMAkGA1UEBhMCVFcxEjAQBgNV
BAoTCVRBSVdBTi1DQTEQMA4GA1UECxMHUm9vdCBDQTEcMBoGA1UEAxMTVFdDQSBHbG9iYWwg
Um9vdCBDQTAeFw0xMjA2MjcwNjI4MzNaFw0zMDEyMzExNTU5NTlaMFExCzAJBgNVBAYTAlRX
MRIwEAYDVQQKEwlUQUlXQU4tQ0ExEDAOBgNVBAsTB1Jvb3QgQ0ExHDAaBgNVBAMTE1RXQ0Eg
R2xvYmFsIFJvb3QgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCwBdvI64zE
booh745NnHEKH1Jw7W2CnJfF10xORUnLQEK1EjRsGcJ0pDFfhQKX7EMzClPSnIyOt7h52yvV
avKOZsTuKwEHktSz0ALfUPZVr2YOy+BHYC8rMjk1Ujoog/h7FsYYuGLWRyWRzvAZEk2tY/XT
P3VfKfChMBwqoJimFb3u/Rk28OKRQ4/6ytYQJ0lM793B8YVwm8rqqFpD/G2Gb3PpN0Wp8DbH
zIh1HrtsBv+baz4X7GGqcXzGHaL3SekVtTzWoWH1EfcFbx39Eb7QMAfCKbAJTibc46KokWof
wpFFiFzlmLhxpRUZyXx1EcxwdE8tmx2RRP1WKKD+u4ZqyPpcC1jcxkt2yKsi2XMPpfRaAok/
T54igu6idFMqPVMnaR1sjjIsZAAmY2E2TqNGtz99sy2sbZCilaLOz9qC5wc0GZbpuCGqKX6m
OL6OKUohZnkfs8O1CWfe1tQHRvMq2uYiN2DLgbYPoA/pyJV/v1WRBXrPPRXAb94JlAGD1zQb
zECl8LibZ9WYkTunhHiVJqRaCPgrdLQABDzfuBSO6N+pjWxnkjMdwLfS7JLIvgm/LCkFbwJr
nu+8vyq8W8BQj0FwcYeyTbcEqYSjMq+u7msXi7Kx/mzhkIyIqJdIzshNy/MGz19qCkKxHh53
L46g5pIOBvwFItIm4TFRfTLcDwIDAQABoyMwITAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/
BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAXzSBdu+WHdXltdkCY4QWwa6gcFGn90xHNcgL
1yg9iXHZqjNB6hQbbCEAwGxCGX6faVsgQt+i0trEfJdLjbDorMjupWkEmQqSpqsnLhpNgb+E
1HAerUf+/UqdM+DyucRFCCEK2mlpc3INvjT+lIutwx4116KD7+U4x6WFH6vPNOw/KP4M8VeG
TslV9xzU2KV9Bnpv1d8Q34FOIWWxtuEXeZVFBs5fzNxGiWNoRI2T9GRwoD2dKAXDOXC4Ynsg
/eTb6QihuJ49CcdP+yz4k3ZB3lLg4VfSnQO8d57+nile98FRYB/e2guyLXW3Q0iT5/Z5xoRd
gFlglPx4mI88k1HtQJAH32RjJMtOcQWh15QaiDLxInQirqWm2BJpTGCjAu4r7NRjkgtevi92
a6O2JryPA9gK8kxkRr05YuWW6zRjESjMlfGt7+/cgFhI6Uu46mWs6fyAtbXIRfmswZ/Zuepi
iI7E8UuDEq3mi4TWnsLrgxifarsbJGAzcMzs9zLzXNl5fe+epP7JI8Mk7hWSsT2RTyaGvWZz
JBPqpK5jwa19hAM8EHiGG3njxPPyBJUgriOCxLM6AGK/5jYk4Ve6xx6QddVfP5VhK8E7zeWz
aGHQRiapIVJpLesux+t3zqY6tQMzT3bR51xUAV3LePTJDL/PEo4XLSNolOer/qmyKwbQBM0=
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIFODCCAyCgAwIBAgIRAJW+FqD3LkbxezmCcvqLzZYwDQYJKoZIhvcNAQEFBQAwNzEUMBIG
A1UECgwLVGVsaWFTb25lcmExHzAdBgNVBAMMFlRlbGlhU29uZXJhIFJvb3QgQ0EgdjEwHhcN
MDcxMDE4MTIwMDUwWhcNMzIxMDE4MTIwMDUwWjA3MRQwEgYDVQQKDAtUZWxpYVNvbmVyYTEf
MB0GA1UEAwwWVGVsaWFTb25lcmEgUm9vdCBDQSB2MTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
ADCCAgoCggIBAMK+6yfwIaPzaSZVfp3FVRaRXP3vIb9TgHot0pGMYzHw7CTww6XScnwQbfQ3
t+XmfHnqjLWCi65ItqwA3GV17CpNX8GH9SBlK4GoRz6JI5UwFpB/6FcHSOcZrr9FZ7E3GwYq
/t75rH2D+1665I+XZ75Ljo1kB1c4VWk0Nj0TSO9P4tNmHqTPGrdeNjPUtAa9GAH9d4RQAEX1
jF3oI7x+/jXh7VB7qTCNGdMJjmhnXb88lxhTuylixcpecsHHltTbLaC0H2kD7OriUPEMPPCs
81Mt8Bz17Ww5OXOAFshSsCPN4D7c3TxHoLs1iuKYaIu+5b9y7tL6pe0S7fyYGKkmdtwoSxAg
HNN/Fnct7W+A90m7UwW7XWjH1Mh1Fj+JWov3F0fUTPHSiXk+TT2YqGHeOh7S+F4D4MHJHIzT
jU3TlTazN19jY5szFPAtJmtTfImMMsJu7D0hADnJoWjiUIMusDor8zagrC/kb2HCUQk5PotT
ubtn2txTuXZZNp1D5SDgPTJghSJRt8czu90VL6R4pgd7gUY2BIbdeTXHlSw7sKMXNeVzH7Rc
We/a6hBle3rQf5+ztCo3O3CLm1u5K7fsslESl1MpWtTwEhDcTwK7EpIvYtQ/aUN8Ddb8WHUB
iJ1YFkveupD/RwGJBmr2X7KQarMCpgKIv7NHfirZ1fpoeDVNAgMBAAGjPzA9MA8GA1UdEwEB
/wQFMAMBAf8wCwYDVR0PBAQDAgEGMB0GA1UdDgQWBBTwj1k4ALP1j5qWDNXr+nuqF+gTEjAN
BgkqhkiG9w0BAQUFAAOCAgEAvuRcYk4k9AwI//DTDGjkk0kiP0Qnb7tt3oNmzqjMDfz1mgbl
dxSR651Be5kqhOX//CHBXfDkH1e3damhXwIm/9fH907eT/j3HEbAek9ALCI18Bmx0GtnLLCo
4MBANzX2hFxc469CeP6nyQ1Q6g2EdvZR74NTxnr/DlZJLo961gzmJ1TjTQpgcmLNkQfWpb/I
mWvtxBnmq0wROMVvMeJuScg/doAmAyYp4Db29iBT4xdwNBedY2gea+zDTYa4EzAvXUYNR0PV
G6pZDrlcjQZIrXSHX8f8MVRBE+LHIQ6e4B4N4cB7Q4WQxYpYxmUKeFfyxiMPAdkgS94P+5KF
dSpcc41teyWRyu5FrgZLAMzTsVlQ2jqIOylDRl6XK1TOU2+NSueW+r9xDkKLfP0ooNBIytrE
gUy7onOTJsjrDNYmiLbAJM+7vVvrdX3pCI6GMyx5dwlppYn8s3CQh3aP0yK7Qs69cwsgJirQ
mz1wHiRszYd2qReWt88NkvuOGKmYSdGe/mBEciG5Ge3C9THxOUiIkCR1VBatzvT4aRRkOfuj
uLpwQMcnHL/EVlP6Y2XQ8xwOFvVrhlhNGNTkDY6lnVuR3HYkUD/GKvvZt5y11ubQ2egZixVx
SK236thZiNSQvxaz2emsWWFUyBy6ysHK4bkgTI86k4mloMy/0/Z1pHWWbVY=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIDwzCCAqugAwIBAgIBATANBgkqhkiG9w0BAQsFADCBgjELMAkGA1UEBhMCREUxKzApBgNV
BAoMIlQtU3lzdGVtcyBFbnRlcnByaXNlIFNlcnZpY2VzIEdtYkgxHzAdBgNVBAsMFlQtU3lz
dGVtcyBUcnVzdCBDZW50ZXIxJTAjBgNVBAMMHFQtVGVsZVNlYyBHbG9iYWxSb290IENsYXNz
IDIwHhcNMDgxMDAxMTA0MDE0WhcNMzMxMDAxMjM1OTU5WjCBgjELMAkGA1UEBhMCREUxKzAp
BgNVBAoMIlQtU3lzdGVtcyBFbnRlcnByaXNlIFNlcnZpY2VzIEdtYkgxHzAdBgNVBAsMFlQt
U3lzdGVtcyBUcnVzdCBDZW50ZXIxJTAjBgNVBAMMHFQtVGVsZVNlYyBHbG9iYWxSb290IENs
YXNzIDIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCqX9obX+hzkeXaXPSi5kfl
82hVYAUdAqSzm1nzHoqvNK38DcLZSBnuaY/JIPwhqgcZ7bBcrGXHX+0CfHt8LRvWurmAwhiC
FoT6ZrAIxlQjgeTNuUk/9k9uN0goOA/FvudocP05l03Sx5iRUKrERLMjfTlH6VJi1hKTXrcx
lkIF+3anHqP1wvzpesVsqXFP6st4vGCvx9702cu+fjOlbpSD8DT6IavqjnKgP6TeMFvvhk1q
lVtDRKgQFRzlAVfFmPHmBiiRqiDFt1MmUUOyCxGVWOHAD3bZwI18gfNycJ5v/hqO2V81xrJv
NHy+SE/iWjnX2J14np+GPgNeGYtEotXHAgMBAAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYD
VR0PAQH/BAQDAgEGMB0GA1UdDgQWBBS/WSA2AHmgoCJrjNXyYdK4LMuCSjANBgkqhkiG9w0B
AQsFAAOCAQEAMQOiYQsfdOhyNsZt+U2e+iKo4YFWz827n+qrkRk4r6p8FU3ztqONpfSO9kSp
p+ghla0+AGIWiPACuvxhI+YzmzB6azZie60EI4RYZeLbK4rnJVM3YlNfvNoBYimipidx5joi
fsFvHZVwIEoHNN/q/xWA5brXethbdXwFeilHfkCoMRN3zUA7tFFHei4R40cR3p1m0IvVVGb6
g1XqfMIpiRvpb7PO4gWEyS8+eIVibslfwXhjdFjASBgMmTnrpMwatXlajRWc2BQN9noHV8ci
gwUtPJslJj0Ys6lDfMjIq2SPDqO/nBudMNva0Bkuqjzx+zOAduTNrRlPBSeOE6Fuwg==
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIDdzCCAl+gAwIBAgIIXDPLYixfszIwDQYJKoZIhvcNAQELBQAwPDEeMBwGA1UEAwwVQXRv
cyBUcnVzdGVkUm9vdCAyMDExMQ0wCwYDVQQKDARBdG9zMQswCQYDVQQGEwJERTAeFw0xMTA3
MDcxNDU4MzBaFw0zMDEyMzEyMzU5NTlaMDwxHjAcBgNVBAMMFUF0b3MgVHJ1c3RlZFJvb3Qg
MjAxMTENMAsGA1UECgwEQXRvczELMAkGA1UEBhMCREUwggEiMA0GCSqGSIb3DQEBAQUAA4IB
DwAwggEKAoIBAQCVhTuXbyo7LjvPpvMpNb7PGKw+qtn4TaA+Gke5vJrf8v7MPkfoepbCJI41
9KkM/IL9bcFyYie96mvr54rMVD6QUM+A1JX76LWC1BTFtqlVJVfbsVD2sGBkWXppzwO3bw2+
yj5vdHLqqjAqc2K+SZFhyBH+DgMq92og3AIVDV4VavzjgsG1xZ1kCWyjWZgHJ8cblithdHFs
Q/H3NYkQ4J7sVaE3IqKHBAUsR320HLliKWYoyrfhk/WklAOZuXCFteZI6o1Q/NnezG8HDt0L
cp2AMBYHlT8oDv3FdU9T1nSatCQujgKRz3bFmx5VdJx4IbHwLfELn8LVlhgf8FQieowHAgMB
AAGjfTB7MB0GA1UdDgQWBBSnpQaxLKYJYO7Rl+lwrrw7GWzbITAPBgNVHRMBAf8EBTADAQH/
MB8GA1UdIwQYMBaAFKelBrEspglg7tGX6XCuvDsZbNshMBgGA1UdIAQRMA8wDQYLKwYBBAGw
LQMEAQEwDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4IBAQAmdzTblEiGKkGdLD4G
kGDEjKwLVLgfuXvTBznk+j57sj1O7Z8jvZfza1zv7v1Apt+hk6EKhqzvINB5Ab149xnYJDE0
BAGmuhWawyfc2E8PzBhj/5kPDpFrdRbhIfzYJsdHt6bPWHJxfrrhTZVHO8mvbaG0weyJ9rQP
OLXiZNwlz6bb65pcmaHFCN795trV1lpFDMS3wrUU77QR/w4VtfX128a961qn8FYiqTxlVMYV
qL2Gns2Dlmh6cYGJ4Qvh6hEbaAjMaZ7snkGeRDImeuKHCnE96+RapNLbxc3G3mB/ufNPRJLv
KrcYPqcZ2Qt9sTdBQrC6YB3y/gkRsPCHe6ed
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIFYDCCA0igAwIBAgIUeFhfLq0sGUvjNwc1NBMotZbUZZMwDQYJKoZIhvcNAQELBQAwSDEL
MAkGA1UEBhMCQk0xGTAXBgNVBAoTEFF1b1ZhZGlzIExpbWl0ZWQxHjAcBgNVBAMTFVF1b1Zh
ZGlzIFJvb3QgQ0EgMSBHMzAeFw0xMjAxMTIxNzI3NDRaFw00MjAxMTIxNzI3NDRaMEgxCzAJ
BgNVBAYTAkJNMRkwFwYDVQQKExBRdW9WYWRpcyBMaW1pdGVkMR4wHAYDVQQDExVRdW9WYWRp
cyBSb290IENBIDEgRzMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCgvlAQjuny
bEC0BJyFuTHK3C3kEakEPBtVwedYMB0ktMPvhd6MLOHBPd+C5k+tR4ds7FtJwUrVu4/sh6x/
gpqG7D0DmVIB0jWerNrwU8lmPNSsAgHaJNM7qAJGr6Qc4/hzWHa39g6QDbXwz8z6+cZM5cOG
MAqNF34168Xfuw6cwI2H44g4hWf6Pser4BOcBRiYz5P1sZK0/CPTz9XEJ0ngnjybCKOLXSoh
4Pw5qlPafX7PGglTvF0FBM+hSo+LdoINofjSxxR3W5A2B4GbPgb6Ul5jxaYA/qXpUhtStZI5
cgMJYr2wYBZupt0lwgNm3fME0UDiTouG9G/lg6AnhF4EwfWQvTA9xO+oabw4m6SkltFi2mnA
AZauy8RRNOoMqv8hjlmPSlzkYZqn0ukqeI1RPToV7qJZjqlc3sX5kCLliEVx3ZGZbHqfPT2Y
fF72vhZooF6uCyP8Wg+qInYtyaEQHeTTRCOQiJ/GKubX9ZqzWB4vMIkIG1SitZgj7Ah3HJVd
YdHLiZxfokqRmu8hqkkWCKi9YSgxyXSthfbZxbGL0eUQMk1fiyA6PEkfM4VZDdvLCXVDaXP7
a3F98N/ETH3Goy7IlXnLc6KOTk0k+17kBL5yG6YnLUlamXrXXAkgt3+UuU/xDRxeiEIbEbfn
kduebPRq34wGmAOtzCjvpUfzUwIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB
/wQEAwIBBjAdBgNVHQ4EFgQUo5fW816iEOGrRZ88F2Q87gFwnMwwDQYJKoZIhvcNAQELBQAD
ggIBABj6W3X8PnrHX3fHyt/PX8MSxEBd1DKquGrX1RUVRpgjpeaQWxiZTOOtQqOCMTaIzen7
xASWSIsBx40Bz1szBpZGZnQdT+3Btrm0DWHMY37XLneMlhwqI2hrhVd2cDMT/uFPpiN3GPoa
jOi9ZcnPP/TJF9zrx7zABC4tRi9pZsMbj/7sPtPKlL92CiUNqXsCHKnQO18LwIE6PWThv6ct
Tr1NxNgpxiIY0MWscgKCP6o6ojoilzHdCGPDdRS5YCgtW2jgFqlmgiNR9etT2DGbe+m3nUvr
iBbP+V04ikkwj+3x6xn0dxoxGE1nVGwvb2X52z3sIexe9PSLymBlVNFxZPT5pqOBMzYzcfCk
eF9OrYMh3jRJjehZrJ3ydlo28hP0r+AJx2EqbPfgna67hkooby7utHnNkDPDs3b69fBsnQGQ
+p6Q9pxyz0fawx/kNSBT8lTR32GDpgLiJTjehTItXnOQUl1CxM49S+H5GYQd1aJQzEH7QRTD
vdbJWqNjZgKAvQU6O0ec7AAmTPWIUb+oI38YB7AL7YsmoWTTYUrrXJ/es69nA7Mf3W1daWhp
q1467HxpvMc7hU6eFbm0FU/DlXpY18ls6Wy58yljXrQs8C097Vpl4KlbQMJImYFtnh8GKjwS
tIsPm6Ik8KaN1nrgS7ZklmOVhMJKzRwuJIczYOXD
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFYDCCA0igAwIBAgIURFc0JFuBiZs18s64KztbpybwdSgwDQYJKoZIhvcNAQELBQAwSDEL
MAkGA1UEBhMCQk0xGTAXBgNVBAoTEFF1b1ZhZGlzIExpbWl0ZWQxHjAcBgNVBAMTFVF1b1Zh
ZGlzIFJvb3QgQ0EgMiBHMzAeFw0xMjAxMTIxODU5MzJaFw00MjAxMTIxODU5MzJaMEgxCzAJ
BgNVBAYTAkJNMRkwFwYDVQQKExBRdW9WYWRpcyBMaW1pdGVkMR4wHAYDVQQDExVRdW9WYWRp
cyBSb290IENBIDIgRzMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQChriWyARjc
V4g/Ruv5r+LrI3HimtFhZiFfqq8nUeVuGxbULX1QsFN3vXg6YOJkApt8hpvWGo6t/x8Vf9WV
HhLL5hSEBMHfNrMWn4rjyduYNM7YMxcoRvynyfDStNVNCXJJ+fKH46nafaF9a7I6JaltUkSs
+L5u+9ymc5GQYaYDFCDy54ejiK2toIz/pgslUiXnFgHVy7g1gQyjO/Dh4fxaXc6AcW34Sas+
O7q414AB+6XrW7PFXmAqMaCvN+ggOp+oMiwMzAkd056OXbxMmO7FGmh77FOm6RQ1o9/NgJ8M
SPsc9PG/Srj61YxxSscfrf5BmrODXfKEVu+lV0POKa2Mq1W/xPtbAd0jIaFYAI7D0GoT7RPj
EiuA3GfmlbLNHiJuKvhB1PLKFAeNilUSxmn1uIZoL1NesNKqIcGY5jDjZ1XHm26sGahVpkUG
0CM62+tlXSoREfA7T8pt9DTEceT/AFr2XK4jYIVz8eQQsSWu1ZK7E8EM4DnatDlXtas1qnIh
O4M15zHfeiFuuDIIfR0ykRVKYnLP43ehvNURG3YBZwjgQQvD6xVu+KQZ2aKrr+InUlYrAoos
FCT5v0ICvybIxo/gbjh9Uy3l7ZizlWNof/k19N+IxWA1ksB8aRxhlRbQ694Lrz4EEEVlWFA4
r0jyWbYW8jwNkALGcC4BrTwV1wIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB
/wQEAwIBBjAdBgNVHQ4EFgQU7edvdlq/YOxJW8ald7tyFnGbxD0wDQYJKoZIhvcNAQELBQAD
ggIBAJHfgD9DCX5xwvfrs4iP4VGyvD11+ShdyLyZm3tdquXK4Qr36LLTn91nMX66AarHakE7
kNQIXLJgapDwyM4DYvmL7ftuKtwGTTwpD4kWilhMSA/ohGHqPHKmd+RCroijQ1h5fq7KpVMN
qT1wvSAZYaRsOPxDMuHBR//47PERIjKWnML2W2mWeyAMQ0GaW/ZZGYjeVYg3UQt4XAoeo0L9
x52ID8DyeAIkVJOviYeIyUqAHerQbj5hLja7NQ4nlv1mNDthcnPxFlxHBlRJAHpYErAK74X9
sbgzdWqTHBLmYF5vHX/JHyPLhGGfHoJE+V+tYlUkmlKY7VHnoX6XOuYvHxHaU4AshZ6rNRDb
Il9qxV6XU/IyAgkwo1jwDQHVcsaxfGl7w/U2Rcxhbl5MlMVerugOXou/983g7aEOGzPuVBj+
D77vfoRrQ+NwmNtddbINWQeFFSM51vHfqSYP1kjHs6Yi9TM3WpVHn3u6GBVv/9YUZINJ0gpn
IdsPNWNgKCLjsZWDzYWm3S8P52dSbrsvhXz1SnPnxT7AvSESBT/8twNJAlvIJebiVDj1eYeM
HVOyToV7BjjHLPj4sHKNJeV3UvQDHEimUF+IIDBu8oJDqz2XhOdT+yHBTw8imoa4WSr2Rz0Z
iC3oheGe7IUIarFsNMkd7EgrO3jtZsSOeWmD3n+M
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFYDCCA0igAwIBAgIULvWbAiin23r/1aOp7r0DoM8Sah0wDQYJKoZIhvcNAQELBQAwSDEL
MAkGA1UEBhMCQk0xGTAXBgNVBAoTEFF1b1ZhZGlzIExpbWl0ZWQxHjAcBgNVBAMTFVF1b1Zh
ZGlzIFJvb3QgQ0EgMyBHMzAeFw0xMjAxMTIyMDI2MzJaFw00MjAxMTIyMDI2MzJaMEgxCzAJ
BgNVBAYTAkJNMRkwFwYDVQQKExBRdW9WYWRpcyBMaW1pdGVkMR4wHAYDVQQDExVRdW9WYWRp
cyBSb290IENBIDMgRzMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCzyw4QZ47q
FJenMioKVjZ/aEzHs286IxSR/xl/pcqs7rN2nXrpixurazHb+gtTTK/FpRp5PIpM/6zfJd5O
2YIyC0TeytuMrKNuFoM7pmRLMon7FhY4futD4tN0SsJiCnMK3UmzV9KwCoWdcTzeo8vAMvMB
OSBDGzXRU7Ox7sWTaYI+FrUoRqHe6okJ7UO4BUaKhvVZR74bbwEhELn9qdIoyhA5CcoTNs+c
ra1AdHkrAj80//ogaX3T7mH1urPnMNA3I4ZyYUUpSFlob3emLoG+B01vr87ERRORFHAGjx+f
+IdpsQ7vw4kZ6+ocYfx6bIrc1gMLnia6Et3UVDmrJqMz6nWB2i3ND0/kA9HvFZcba5DFApCT
ZgIhsUfei5pKgLlVj7WiL8DWM2fafsSntARE60f75li59wzweyuxwHApw0BiLTtIadwjPEjr
ewl5qW3aqDCYz4ByA4imW0aucnl8CAMhZa634RylsSqiMd5mBPfAdOhx3v89WcyWJhKLhZVX
GqtrdQtEPREoPHtht+KPZ0/l7DxMYIBpVzgeAVuNVejH38DMdyM0SXV89pgR6y3e7UEuFAUC
f+D+IOs15xGsIs5XPd7JMG0QA4XN8f+MFrXBsj6IbGB/kE+V9/YtrQE5BwT6dYB9v0lQ7e/J
xHwc64B+27bQ3RP+ydOc17KXqQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB
/wQEAwIBBjAdBgNVHQ4EFgQUxhfQvKjqAkPyGwaZXSuQILnXnOQwDQYJKoZIhvcNAQELBQAD
ggIBADRh2Va1EodVTd2jNTFGu6QHcrxfYWLopfsLN7E8trP6KZ1/AvWkyaiTt3pxKGmPc+FS
kNrVvjrlt3ZqVoAh313m6Tqe5T72omnHKgqwGEfcIHB9UqM+WXzBusnIFUBhynLWcKzSt/Ac
5IYp8M7vaGPQtSCKFWGafoaYtMnCdvvMujAWzKNhxnQT5WvvoxXqA/4Ti2Tk08HS6IT7SdEQ
TXlm66r99I0xHnAUrdzeZxNMgRVhvLfZkXdxGYFgu/BYpbWcC/ePIlUnwEsBbTuZDdQdm2Nn
L9DuDcpmvJRPpq3t/O5jrFc/ZSXPsoaP0Aj/uHYUbt7lJ+yreLVTubY/6CD50qi+YUbKh4yE
8/nxoGibIh6BJpsQBJFxwAYf3KDTuVan45gtf4Od34wrnDKOMpTwATwiKp9Dwi7DmDkHOHv8
XgBCH/MyJnmDhPbl8MFREsALHgQjDFSlTC9JxUrRtm5gDWv8a4uFJGS3iQ6rJUdbPM9+Sb3H
6QrG2vd+DhcI00iX0HGS8A85PjRqHH3Y8iKuu2n0M7SmSFXRDw4m6Oy2Cy2nhTXN/VnIn9HN
PlopNLk9hM6xZdRZkZFWdSHBd575euFgndOtBBj0fOtek49TSiIp+EgrPk2GrFt/ywaZWWDY
WGWVjUTR939+J399roD1B0y2PpxxVJkES/1Y+Zj0
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDljCCAn6gAwIBAgIQC5McOtY5Z+pnI7/Dr5r0SzANBgkqhkiG9w0BAQsFADBlMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgRzIwHhcNMTMwODAxMTIw
MDAwWhcNMzgwMTE1MTIwMDAwWjBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1
cmVkIElEIFJvb3QgRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDZ5ygvUj82
ckmIkzTz+GoeMVSAn61UQbVH35ao1K+ALbkKz3X9iaV9JPrjIgwrvJUXCzO/GU1BBpAAvQxN
EP4HteccbiJVMWWXvdMX0h5i89vqbFCMP4QMls+3ywPgym2hFEwbid3tALBSfK+RbLE4E9Hp
EgjAALAcKxHad3A2m67OeYfcgnDmCXRwVWmvo2ifv922ebPynXApVfSr/5Vh88lAbx3RvpO7
04gqu52/clpWcTs/1PPRCv4o76Pu2ZmvA9OPYLfykqGxvYmJHzDNw6YuYjOuFgJ3RFrngQo8
p0Quebg/BLxcoIfhG69Rjs3sLPr4/m3wOnyqi+RnlTGNAgMBAAGjQjBAMA8GA1UdEwEB/wQF
MAMBAf8wDgYDVR0PAQH/BAQDAgGGMB0GA1UdDgQWBBTOw0q5mVXyuNtgv6l+vVa1lzan1jAN
BgkqhkiG9w0BAQsFAAOCAQEAyqVVjOPIQW5pJ6d1Ee88hjZv0p3GeDgdaZaikmkuOGybfQTU
iaWxMTeKySHMq2zNixya1r9I0jJmwYrA8y8678Dj1JGG0VDjA9tzd29KOVPt3ibHtX2vK0LR
dWLjSisCx1BL4GnilmwORGYQRI+tBev4eaymG+g3NJ1TyWGqolKvSnAWhsI6yLETcDbYz+70
CjTVW0z9B5yiutkBclzzTcHdDrEcDcRjvq30FPuJ7KJBDkzMyFdA0G4Dqs0MjomZmWzwPDCv
ON9vvKO+KSAnq3T/EyJ43pdSVR6DtVQgA+6uwE9W3jfMw3+qBCe703e4YtsXfJwoIhNzbM8m
9Yop5w==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICRjCCAc2gAwIBAgIQC6Fa+h3foLVJRK/NJKBs7DAKBggqhkjOPQQDAzBlMQswCQYDVQQG
EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
MSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgRzMwHhcNMTMwODAxMTIwMDAw
WhcNMzgwMTE1MTIwMDAwWjBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
IElEIFJvb3QgRzMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQZ57ysRGXtzbg/WPuNsVepRC0F
FfLvC/8QdJ+1YlJfZn4f5dwbRXkLzMZTCp2NXQLZqVneAlr2lSoOjThKiknGvMYDOAdfVdp+
CW7if17QRSAPWXYQ1qAk8C3eNvJsKTmjQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/
BAQDAgGGMB0GA1UdDgQWBBTL0L2p4ZgFUaFNN6KDec6NHSrkhDAKBggqhkjOPQQDAwNnADBk
AjAlpIFFAmsSS3V0T8gj43DydXLefInwz5FyYZ5eEJJZVrmDxxDnOOlYJjZ91eQ0hjkCMHw2
U/Aw5WJjOpnitqM7mzT6HtoQknFekROn3aRukswy1vUhZscv6pZjamVFkpUBtA==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBhMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBHMjAeFw0xMzA4MDExMjAwMDBa
Fw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBS
b290IEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/
RrohCgiN9RlUyfuI2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxps
MNzaHxmx1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ
q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5WztCO7TG1F
8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQvIOlCsRnKPZzFBQ9
RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4G
A1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcN
AQELBQADggEBAGBnKJRvDkhj6zHd6mcY1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVn
NeyIv/iPsGEMNKSuIEyExtv4NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2Z
L7tcu7XUIOGZX1NGFdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUT
Fy8bJZ918rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe
pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTflMrY=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIICPzCCAcWgAwIBAgIQBVVWvPJepDU1w6QP1atFcjAKBggqhkjOPQQDAzBhMQswCQYDVQQG
EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
MSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBHMzAeFw0xMzA4MDExMjAwMDBaFw0z
ODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290
IEczMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE3afZu4q4C/sLfyHS8L6+c/MzXRq8NOrexpu8
0JX28MzQC7phW1FGfp4tn+6OYwwX7Adw9c+ELkCDnOg/QW07rdOkFFk2eJ0DQ+4QE2xy3q6I
p6FrtUPOZ9wj/wMco+I+o0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAd
BgNVHQ4EFgQUs9tIpPmhxdiuNkHMEWNpYim8S8YwCgYIKoZIzj0EAwMDaAAwZQIxAK288mw/
EkrRLTnDCgmXc/SINoyIJ7vmiI1Qhadj+Z4y3maTD/HMsQmP3Wyr+mt/oAIwOWZbwmSNuJ5Q
3KjVSaLtx9zRSX8XAbjIho9OjIgrqJqpisXRAL34VOKa5Vt8sycX
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIFkDCCA3igAwIBAgIQBZsbV56OITLiOQe9p3d1XDANBgkqhkiG9w0BAQwFADBiMQswCQYD
VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
Y29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMTMwODAxMTIwMDAw
WhcNMzgwMTE1MTIwMDAwWjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVk
IFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAi
MGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/W
BTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDV
ySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw
2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1
EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADk
RSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+
9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m8
00ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn1
5GkvmB0t9dmpsh3lGwIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIB
hjAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wDQYJKoZIhvcNAQEMBQADggIBALth
2X2pbL4XxJEbw6GiAI3jZGgPVs93rnD5/ZpKmbnJeFwMDF/k5hQpVgs2SV1EY+CtnJYYZhsj
DT156W1r1lT40jzBQ0CuHVD1UvyQO7uYmWlrx8GnqGikJ9yd+SeuMIW59mdNOj6PWTkiU0Tr
yF0Dyu1Qen1iIQqAyHNm0aAFYF/opbSnr6j3bTWcfFqK1qI4mfN4i/RN0iAL3gTujJtHgXIN
wBQy7zBZLq7gcfJW5GqXb5JQbZaNaHqasjYUegbyJLkJEVDXCLG4iXqEI2FCKeWjzaIgQdfR
nGTZ6iahixTXTBmyUEFxPT9NcCOGDErcgdLMMpSEDQgJlxxPwO5rIHQw0uA5NBCFIRUBCOhV
Mt5xSdkoF1BN5r5N0XWs0Mr7QbhDparTwwVETyw2m+L64kW4I1NsBm9nVX9GtUw/bihaeSbS
pKhil9Ie4u1Ki7wb/UdKDd9nZn6yW0HQO+T0O/QEY+nvwlQAUaCKKsnOeMzV6ocEGLPOr0mI
r/OSmbaz5mEP0oUA51Aa5BuVnRmhuZyxm7EAHu/QD09CbMkKvO5D+jpxpchNJqU1/YldvIVi
HTLSoCtU7ZpXwdv6EM8Zt4tKG48BtieVU+i2iW1bvGjUI+iLUaJW+fCmgKDWHrO8Dw9TdSmq
6hN35N6MgSGtBxBHEa2HPQfRdbzP82Z+
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIF2DCCA8CgAwIBAgIQTKr5yttjb+Af907YWwOGnTANBgkqhkiG9w0BAQwFADCBhTELMAkG
A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9y
ZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBSU0EgQ2Vy
dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMTE5MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCB
hTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMH
U2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBS
U0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQCR6FSS0gpWsawNJN3Fz0RndJkrN6N9I3AAcbxT38T6KhKPS38QVr2fcHK3YX/JSw8X
pz3jsARh7v8Rl8f0hj4K+j5c+ZPmNHrZFGvnnLOFoIJ6dq9xkNfs/Q36nGz637CC9BR++b7E
pi9Pf5l/tfxnQ3K9DADWietrLNPtj5gcFKt+5eNu/Nio5JIk2kNrYrhV/erBvGy2i/MOjZrk
m2xpmfh4SDBF1a3hDTxFYPwyllEnvGfDyi62a+pGx8cgoLEfZd5ICLqkTqnyg0Y3hOvozIFI
Q2dOciqbXL1MGyiKXCJ7tKuY2e7gUYPDCUZObT6Z+pUX2nwzV0E8jVHtC7ZcryxjGt9XyD+8
6V3Em69FmeKjWiS0uqlWPc9vqv9JWL7wqP/0uK3pN/u6uPQLOvnoQ0IeidiEyxPx2bvhiWC4
jChWrBQdnArncevPDt09qZahSL0896+1DSJMwBGB7FY79tOi4lu3sgQiUpWAk2nojkxl8ZED
LXB0AuqLZxUpaVICu9ffUGpVRr+goyhhf3DQw6KqLCGqR84onAZFdr+CGCe01a60y1Dma/RM
hnEw6abfFobg2P9A3fvQQoh/ozM6LlweQRGBY84YcWsr7KaKtzFcOmpH4MN5WdYgGq/yapiq
crxXStJLnbsQ/LBMQeXtHT1eKJ2czL+zUdqnR+WEUwIDAQABo0IwQDAdBgNVHQ4EFgQUu69+
Aj36pvE8hI6t7jiY7NkyMtQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wDQYJ
KoZIhvcNAQEMBQADggIBAArx1UaEt65Ru2yyTUEUAJNMnMvlwFTPoCWOAvn9sKIN9SCYPBMt
rFaisNZ+EZLpLrqeLppysb0ZRGxhNaKatBYSaVqM4dc+pBroLwP0rmEdEBsqpIt6xf4FpuHA
1sj+nq6PK7o9mfjYcwlYRm6mnPTXJ9OV2jeDchzTc+CiR5kDOF3VSXkAKRzH7JsgHAckaVd4
sjn8OoSgtZx8jb8uk2IntznaFxiuvTwJaP+EmzzV1gsD41eeFPfR60/IvYcjt7ZJQ3mFXLrr
kguhxuhoqEwWsRqZCuhTLJK7oQkYdQxlqHvLI7cawiiFwxv/0Cti76R7CZGYZ4wUAc1oBmpj
IXUDgIiKboHGhfKppC3n9KUkEEeDys30jXlYsQab5xoq2Z0B15R97QNKyvDb6KkBPvVWmcke
jkk9u+UJueBPSZI9FoJAzMxZxuY67RIuaTxslbH9qh17f4a+Hg4yRvv7E491f0yLS0Zj/gA0
QHDBw7mh3aZw4gSzQbzpgJHqZJx64SIDqZxubw5lT2yHh17zbqD5daWbQOhTsiedSrnAdyGN
/4fy3ryM7xfft0kL0fJuMAsaDk527RH89elWsn2/x20Kk4yl0MC2Hb46TpSi125sC8KKfPog
88Tk5c0NqMuRkrF8hey1FGlmDoLnzc7ILaZRfyHBNVOFBkpdn627G190
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIF3jCCA8agAwIBAgIQAf1tMPyjylGoG7xkDjUDLTANBgkqhkiG9w0BAQwFADCBiDELMAkG
A1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4w
HAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0Eg
Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMjAxMDAwMDAwWhcNMzgwMTE4MjM1OTU5
WjCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJU
cnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4IC
DwAwggIKAoICAQCAEmUXNg7D2wiz0KxXDXbtzSfTTK1Qg2HiqiBNCS1kCdzOiZ/MPans9s/B
3PHTsdZ7NygRK0faOca8Ohm0X6a9fZ2jY0K2dvKpOyuR+OJv0OwWIJAJPuLodMkYtJHUYmTb
f6MG8YgYapAiPLz+E/CHFHv25B+O1ORRxhFnRghRy4YUVD+8M/5+bJz/Fp0YvVGONaanZshy
Z9shZrHUm3gDwFA66Mzw3LyeTP6vBZY1H1dat//O+T23LLb2VN3I5xI6Ta5MirdcmrS3ID3K
fyI0rn47aGYBROcBTkZTmzNg95S+UzeQc0PzMsNT79uq/nROacdrjGCT3sTHDN/hMq7MkztR
eJVni+49Vv4M0GkPGw/zJSZrM233bkf6c0Plfg6lZrEpfDKEY1WJxA3Bk1QwGROs0303p+td
Omw1XNtB1xLaqUkL39iAigmTYo61Zs8liM2EuLE/pDkP2QKe6xJMlXzzawWpXhaDzLhn4ugT
ncxbgtNMs+1b/97lc6wjOy0AvzVVdAlJ2ElYGn+SNuZRkg7zJn0cTRe8yexDJtC/QV9AqURE
9JnnV4eeUB9XVKg+/XRjL7FQZQnmWEIuQxpMtPAlR1n6BB6T1CZGSlCBst6+eLf8ZxXhyVeE
Hg9j1uliutZfVS7qXMYoCAQlObgOK6nyTJccBz8NUvXt7y+CDwIDAQABo0IwQDAdBgNVHQ4E
FgQUU3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMB
Af8wDQYJKoZIhvcNAQEMBQADggIBAFzUfA3P9wF9QZllDHPFUp/L+M+ZBn8b2kMVn54CVVeW
FPFSPCeHlCjtHzoBN6J2/FNQwISbxmtOuowhT6KOVWKR82kV2LyI48SqC/3vqOlLVSoGIG1V
eCkZ7l8wXEskEVX/JJpuXior7gtNn3/3ATiUFJVDBwn7YKnuHKsSjKCaXqeYalltiz8I+8jR
Ra8YFWSQEg9zKC7F4iRO/Fjs8PRF/iKz6y+O0tlFYQXBl2+odnKPi4w2r78NBc5xjeambx9s
pnFixdjQg3IM8WcRiQycE0xyNN+81XHfqnHd4blsjDwSXWXavVcStkNr/+XeTWYRUc+ZruwX
tuhxkYzeSf7dNXGiFSeUHM9h4ya7b6NnJSFd5t0dCy5oGzuCr+yDZ4XUmFF0sbmZgIn/f3gZ
XHlKYC6SQK5MNyosycdiyA5d9zZbyuAlJQG03RoHnHcAP9Dc1ew91Pq7P8yF1m9/qS3fuQL3
9ZeatTXaw2ewh0qpKJ4jjv9cJ2vhsE/zB+4ALtRZh8tSQZXq9EfX7mRBVXyNWQKV3WKdwrnu
Wih0hKWbt5DHDAff9Yk2dDLWKMGwsAvgnEzDHNb842m1R0aBL6KCq9NjRHDEjf8tM7qtj3u1
cIiuPhnPQCjY/MiQu12ZIvVS5ljFH4gxQ+6IHdfGjjxDah2nGN59PRbxYvnKkKj9
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIICjzCCAhWgAwIBAgIQXIuZxVqUxdJxVt7NiYDMJjAKBggqhkjOPQQDAzCBiDELMAkGA1UE
BhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYD
VQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBFQ0MgQ2Vy
dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMjAxMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCB
iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBD
aXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVz
dCBFQ0MgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQa
rFRaqfloI+d61SRvU8Za2EurxtW20eZzca7dnNYMYf3boIkDuAUU7FfO7l0/4iGzzvfUinng
o4N+LZfQYcTxmdwlkWOrfzCjtHDix6EznPO/LlxTsV+zfTJ/ijTjeXmjQjBAMB0GA1UdDgQW
BBQ64QmG1M8ZwpZ2dEl23OA1xmNjmjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB
/zAKBggqhkjOPQQDAwNoADBlAjA2Z6EWCNzklwBBHU6+4WMBzzuqQhFkoJ2UOQIReVx7Hfpk
ue4WQrO/isIJxOzksU0CMQDpKmFHjFJKS04YcPbWRNZu9YO6bVi9JNlWSOrvxKJGgYhqOkbR
qZtNyWHa0V1Xahg=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIICHjCCAaSgAwIBAgIRYFlJ4CYuu1X5CneKcflK2GwwCgYIKoZIzj0EAwMwUDEkMCIGA1UE
CxMbR2xvYmFsU2lnbiBFQ0MgUm9vdCBDQSAtIFI1MRMwEQYDVQQKEwpHbG9iYWxTaWduMRMw
EQYDVQQDEwpHbG9iYWxTaWduMB4XDTEyMTExMzAwMDAwMFoXDTM4MDExOTAzMTQwN1owUDEk
MCIGA1UECxMbR2xvYmFsU2lnbiBFQ0MgUm9vdCBDQSAtIFI1MRMwEQYDVQQKEwpHbG9iYWxT
aWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAER0UOlvt9
Xb/pOdEh+J8LttV7HpI6SFkc8GIxLcB6KP4ap1yztsyX50XUWPrRd21DosCHZTQKH3rd6zwz
ocWdTaRvQZU4f8kehOvRnkmSh5SHDDqFSmafnVmTTZdhBoZKo0IwQDAOBgNVHQ8BAf8EBAMC
AQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUPeYpSJvqB8ohREom3m7e0oPQn1kwCgYI
KoZIzj0EAwMDaAAwZQIxAOVpEslu28YxuglB4Zf4+/2a4n0Sye18ZNPLBSWLVtmg515dTguD
nFt2KaAJJiFqYgIwcdK1j1zqO+F4CYWodZI7yFz9SO8NdCKoCOJuxUnOxwy8p2Fp8fc74SrL
+SvzZpA3
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFYDCCA0igAwIBAgIQCgFCgAAAAUUjyES1AAAAAjANBgkqhkiG9w0BAQsFADBKMQswCQYD
VQQGEwJVUzESMBAGA1UEChMJSWRlblRydXN0MScwJQYDVQQDEx5JZGVuVHJ1c3QgQ29tbWVy
Y2lhbCBSb290IENBIDEwHhcNMTQwMTE2MTgxMjIzWhcNMzQwMTE2MTgxMjIzWjBKMQswCQYD
VQQGEwJVUzESMBAGA1UEChMJSWRlblRydXN0MScwJQYDVQQDEx5JZGVuVHJ1c3QgQ29tbWVy
Y2lhbCBSb290IENBIDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCnUBneP5k9
1DNG8W9RYYKyqU+PZ4ldhNlT3Qwo2dfw/66VQ3KZ+bVdfIrBQuExUHTRgQ18zZshq0PirK1e
hm7zCYofWjK9ouuU+ehcCuz/mNKvcbO0U59Oh++SvL3sTzIwiEsXXlfEU8L2ApeN2WIrvyQf
Yo3fw7gpS0l4PJNgiCL8mdo2yMKi1CxUAGc1bnO/AljwpN3lsKImesrgNqUZFvX9t++uP0D1
bVoE/c40yiTcdCMbXTMTEl3EASX2MN0CXZ/g1Ue9tOsbobtJSdifWwLziuQkkORiT0/Br4sO
dBeo0XKIanoBScy0RnnGF7HamB4HWfp1IYVl3ZBWzvurpWCdxJ35UrCLvYf5jysjCiN2O/cz
4ckA82n5S6LgTrx+kzmEB/dEcH7+B1rlsazRGMzyNeVJSQjKVsk9+w8YfYs7wRPCTY/JTw43
6R+hDmrfYi7LNQZReSzIJTj0+kuniVyc0uMNOYZKdHzVWYfCP04MXFL0PfdSgvHqo6z9STQa
KPNBiDoT7uje/5kdX7rL6B7yuVBgwDHTc+XvvqDtMwt0viAgxGds8AgDelWAf0ZOlqf0Hj7h
9tgJ4TNkK2PXMl6f+cB7D3hvl7yTmvmcEpB4eoCHFddydJxVdHixuuFucAS6T6C6aMN7/zHw
cz09lCqxC0EOoP5NiGVreTO01wIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQU7UQZwNPwBovupHu+QucmVMiONnYwDQYJKoZIhvcNAQELBQAD
ggIBAA2ukDL2pkt8RHYZYR4nKM1eVO8lvOMIkPkp165oCOGUAFjvLi5+U1KMtlwH6oi6mYtQ
lNeCgN9hCQCTrQ0U5s7B8jeUeLBfnLOic7iPBZM4zY0+sLj7wM+x8uwtLRvM7Kqas6pgghst
O8OEPVeKlh6cdbjTMM1gCIOQ045U8U1mwF10A0Cj7oV+wh93nAbowacYXVKV7cndJZ5t+qnt
ozo00Fl72u1Q8zW/7esUTTHHYPTa8Yec4kjixsU3+wYQ+nVZZjFHKdp2mhzpgq7vmrlR94gj
mmmVYjzlVYA211QC//G5Xc7UI2/YRYRKW2XviQzdFKcgyxilJbQN+QHwotL0AMh0jqEqSI5l
2xPE4iUXfeu+h1sXIFRRk0pTAwvsXcoz7WL9RccvW9xYoIA55vrX/hMUpu09lEpCdNTDd1lz
zY9GvlU47/rokTLql1gEIt44w8y8bckzOmoKaT+gyOpyj4xjhiO9bTyWnpXgSUyqorkqG5w2
gXjtw+hG4iZZRHUe2XWJUc0QhJ1hYMtd+ZciTY6Y5uN/9lu7rs3KSoFrXgvzUeF0K+l+J6fZ
mUlO+KWA2yUPHGNiiskzZ2s8EIPGrd6ozRaOjfAHN3Gf8qv8QfXBi+wAN10J5U6A7/qxXDgG
pRtK4dw4LTzcqx+QGtVKnO7RcGzM7vRX+Bi6hG6H
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFZjCCA06gAwIBAgIQCgFCgAAAAUUjz0Z8AAAAAjANBgkqhkiG9w0BAQsFADBNMQswCQYD
VQQGEwJVUzESMBAGA1UEChMJSWRlblRydXN0MSowKAYDVQQDEyFJZGVuVHJ1c3QgUHVibGlj
IFNlY3RvciBSb290IENBIDEwHhcNMTQwMTE2MTc1MzMyWhcNMzQwMTE2MTc1MzMyWjBNMQsw
CQYDVQQGEwJVUzESMBAGA1UEChMJSWRlblRydXN0MSowKAYDVQQDEyFJZGVuVHJ1c3QgUHVi
bGljIFNlY3RvciBSb290IENBIDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC2
IpT8pEiv6EdrCvsnduTyP4o7ekosMSqMjbCpwzFrqHd2hCa2rIFCDQjrVVi7evi8ZX3yoG2L
qEfpYnYeEe4IFNGyRBb06tD6Hi9e28tzQa68ALBKK0CyrOE7S8ItneShm+waOh7wCLPQ5CQ1
B5+ctMlSbdsHyo+1W/CD80/HLaXIrcuVIKQxKFdYWuSNG5qrng0M8gozOSI5Cpcu81N3uURF
/YTLNiCBWS2ab21ISGHKTN9T0a9SvESfqy9rg3LvdYDaBjMbXcjaY8ZNzaxmMc3R3j6HEDbh
uaR672BQssvKplbgN6+rNBM5Jeg5ZuSYeqoSmJxZZoY+rfGwyj4GD3vwEUs3oERte8uojHH0
1bWRNszwFcYr3lEXsZdMUD2xlVl8BX0tIdUAvwFnol57plzy9yLxkA2T26pEUWbMfXYD62qo
KjgZl3YNa4ph+bz27nb9cCvdKTz4Ch5bQhyLVi9VGxyhLrXHFub4qjySjmm2AcG1hp2JDws4
lFTo6tyePSW8Uybt1as5qsVATFSrsrTZ2fjXctscvG29ZV/viDUqZi/u9rNl8DONfJhBaUYP
Qxxp+pu10GFqzcpL2UyQRqsVWaFHVCkugyhfHMKiq3IXAAaOReyL4jM9f9oZRORicsPfIsby
VtTdX5Vy7W1f90gDW/3FKqD2cyOEEBsB5wIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYD
VR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU43HgntinQtnbcZFrlJPrw6PRFKMwDQYJKoZIhvcN
AQELBQADggIBAEf63QqwEZE4rU1d9+UOl1QZgkiHVIyqZJnYWv6IAcVYpZmxI1Qjt2odIFfl
AWJBF9MJ23XLblSQdf4an4EKwt3X9wnQW3IV5B4Jaj0z8yGa5hV+rVHVDRDtfULAj+7AmgjV
QdZcDiFpboBhDhXAuM/FSRJSzL46zNQuOAXeNf0fb7iAaJg9TaDKQGXSc3z1i9kKlT/YPyNt
GtEqJBnZhbMX73huqVjRI9PHE+1yJX9dsXNw0H8GlwmEKYBhHfpe/3OsoOOJuBxxFcbeMX8S
3OFtm6/n6J91eEyrRjuazr8FGF1NFTwWmhlQBJqymm9li1JfPFgEKCXAZmExfrngdbkaqIHW
chezxQMxNRF4eKLg6TCMf4DfWN88uieW4oA0beOY02QnrEh+KHdcxiVhJfiFDGX6xDIvpZgF
5PgLZxYWxoK4Mhn5+bl53B/N66+rDt0b20XkeucC4pVd/GnwU2lhlXV5C15V5jgclKlZM57I
cXR5f1GJtshquDDIajjDbp7hNxbqBWJMWxJH7ae0s1hWx0nzfxJoCTFx8G34Tkf71oXuxVhA
GaQdp/lLQzfcaFpPz+vCZHTetBXZ9FRUGi8c15dxVJCO2SCdUyt/q4/i6jC8UDfv8Ue1fXws
BOxonbRJRBD0ckscZOf85muQ3Wl9af0AVqW3rLatt8o+Ae+c
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIEPjCCAyagAwIBAgIESlOMKDANBgkqhkiG9w0BAQsFADCBvjELMAkGA1UEBhMCVVMxFjAU
BgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVn
YWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9y
aXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVzdCBSb290IENlcnRpZmljYXRpb24gQXV0
aG9yaXR5IC0gRzIwHhcNMDkwNzA3MTcyNTU0WhcNMzAxMjA3MTc1NTU0WjCBvjELMAkGA1UE
BhMCVVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVz
dC5uZXQvbGVnYWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDA5IEVudHJ1c3QsIEluYy4gLSBm
b3IgYXV0aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVzdCBSb290IENlcnRpZmlj
YXRpb24gQXV0aG9yaXR5IC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6
hLZy254Ma+KZ6TABp3bqMriVQRrJ2mFOWHLP/vaCeb9zYQYKpSfYs1/TRU4cctZOMvJyig/3
gxnQaoCAAEUesMfnmr8SVycco2gvCoe9amsOXmXzHHfV1IWNcCG0szLni6LVhjkCsbjSR87k
yUnEO6fe+1R9V77w6G7CebI6C1XiUJgWMhNcL3hWwcKUs/Ja5CeanyTXxuzQmyWC48zCxEXF
jJd6BmsqEZ+pCm5IO2/b1BEZQvePB7/1U1+cPvQXLOZprE4yTGJ36rfo5bs0vBmLrpxR57d+
tVOxMyLlbc9wPBr64ptntoP0jaWvYkxN4FisZDQSA/i2jZRjJKRxAgMBAAGjQjBAMA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRqciZ60B7vfec7aVHUbI2f
kBJmqzANBgkqhkiG9w0BAQsFAAOCAQEAeZ8dlsa2eT8ijYfThwMEYGprmi5ZiXMRrEPR9RP/
jTkrwPK9T3CMqS/qF8QLVJ7UG5aYMzyorWKiAHarWWluBh1+xLlEjZivEtRh2woZRkfz6/dj
wUAFQKXSt/S1mja/qYh2iARVBCuch38aNzx+LaUa2NSJXsq9rD1s2G2v1fN2D807iDginWyT
msQ9v4IbZT+mD12q/OWyFcq1rca8PdCE6OoGcrBNOTJ4vz4RnAuknZoh8/CbCzB428Hch0P+
vGOaysXCHMnHjf87ElgI5rY97HosTvuDls4MPGmHVHOkc8KT/1EQrBVUAdj8BbGJoX90g5pJ
19xOe4pIb4tF9g==
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIC+TCCAoCgAwIBAgINAKaLeSkAAAAAUNCR+TAKBggqhkjOPQQDAzCBvzELMAkGA1UEBhMC
VVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5u
ZXQvbGVnYWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDEyIEVudHJ1c3QsIEluYy4gLSBmb3Ig
YXV0aG9yaXplZCB1c2Ugb25seTEzMDEGA1UEAxMqRW50cnVzdCBSb290IENlcnRpZmljYXRp
b24gQXV0aG9yaXR5IC0gRUMxMB4XDTEyMTIxODE1MjUzNloXDTM3MTIxODE1NTUzNlowgb8x
CzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSgwJgYDVQQLEx9TZWUgd3d3
LmVudHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQLEzAoYykgMjAxMiBFbnRydXN0LCBJ
bmMuIC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxMzAxBgNVBAMTKkVudHJ1c3QgUm9vdCBD
ZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEVDMTB2MBAGByqGSM49AgEGBSuBBAAiA2IABIQT
ydC6bUF74mzQ61VfZgIaJPRbiWlH47jCffHyAsWfoPZb1YsGGYZPUxBtByQnoaD41UcZYUx9
ypMn6nQM72+WCf5j7HBdNq1nd67JnXxVRDqiY1Ef9eNi1KlHBz7MIKNCMEAwDgYDVR0PAQH/
BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLdj5xrdjekIplWDpOBqUEFlEUJJ
MAoGCCqGSM49BAMDA2cAMGQCMGF52OVCR98crlOZF7ZvHH3hvxGU0QOIdeSNiaSKd0bebWHv
AvX7td/M/k7//qnmpwIwW5nXhTcGtXsI/esni0qU+eH6p44mCOh8kmhtc9hvJqwhAriZtyZB
WyVgrtBIGu4G
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFjTCCA3WgAwIBAgIEGErM1jANBgkqhkiG9w0BAQsFADBWMQswCQYDVQQGEwJDTjEwMC4G
A1UECgwnQ2hpbmEgRmluYW5jaWFsIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRUwEwYDVQQD
DAxDRkNBIEVWIFJPT1QwHhcNMTIwODA4MDMwNzAxWhcNMjkxMjMxMDMwNzAxWjBWMQswCQYD
VQQGEwJDTjEwMC4GA1UECgwnQ2hpbmEgRmluYW5jaWFsIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRUwEwYDVQQDDAxDRkNBIEVWIFJPT1QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQDXXWvNED8fBVnVBU03sQ7smCuOFR36k0sXgiFxEFLXUWRwFsJVaU2OFW2fvwwbwuCj
Z9YMrM8irq93VCpLTIpTUnrD7i7es3ElweldPe6hL6P3KjzJIx1qqx2hp/Hz7KDVRM8Vz3Iv
HWOX6Jn5/ZOkVIBMUtRSqy5J35DNuF++P96hyk0g1CXohClTt7GIH//62pCfCqktQT+x8Rgp
7hZZLDRJGqgG16iI0gNyejLi6mhNbiyWZXvKWfry4t3uMCz7zEasxGPrb382KzRzEpR/38wm
nvFyXVBlWY9ps4deMm/DGIq1lY+wejfeWkU7xzbh72fROdOXW3NiGUgthxwG+3SYIElz8AXS
G7Ggo7cbcNOIabla1jj0Ytwli3i/+Oh+uFzJlU9fpy25IGvPa931DfSCt/SyZi4QKPaXWnuW
Fo8BGS1sbn85WAZkgwGDg8NNkt0yxoekN+kWzqotaK8KgWU6cMGbrU1tVMoqLUuFG7OA5nBF
DWteNfB/O7ic5ARwiRIlk9oKmSJgamNgTnYGmE69g60dWIolhdLHZR4tjsbftsbhf4oEIRUp
dPA+nJCdDC7xij5aqgwJHsfVPKPtl8MeNPo4+QgO48BdK4PRVmrJtqhUUy54Mmc9gn900Pvh
tgVguXDbjgv5E1hvcWAQUhC5wUEJ73IfZzF4/5YFjQIDAQABo2MwYTAfBgNVHSMEGDAWgBTj
/i39KNALtbq2osS/BqoFjJP7LzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAd
BgNVHQ4EFgQU4/4t/SjQC7W6tqLEvwaqBYyT+y8wDQYJKoZIhvcNAQELBQADggIBACXGumvr
h8vegjmWPfBEp2uEcwPenStPuiB/vHiyz5ewG5zz13ku9Ui20vsXiObTej/tUxPQ4i9qecsA
IyjmHjdXNYmEwnZPNDatZ8POQQaIxffu2Bq41gt/UP+TqhdLjOztUmCypAbqTuv0axn96/Ua
4CUqmtzHQTb3yHQFhDmVOdYLO6Qn+gjYXB74BGBSESgoA//vU2YApUo0FmZ8/Qmkrp5nGm9B
C2sGE5uPhnEFtC+NiWYzKXZUmhH4J/qyP5Hgzg0b8zAarb8iXRvTvyUFTeGSGn+ZnzxEk8rU
QElsgIfXBDrDMlI1Dlb4pd19xIsNER9Tyx6yF7Zod1rg1MvIB671Oi6ON7fQAUtDKXeMOZeP
glr4UeWJoBjnaH9dCi77o0cOPaYjesYBx4/IXr9tgFa+iiS6M+qf4TIRnvHST4D2G0CvOJ4R
UHlzEhLN5mydLIhyPDCBBpEi6lmt2hkuIsKNuYyH4Ga8cyNfIWRjgEj1oDwYPZTISEEdQLpe
/v5WOaHIz16eGWRGENoXkbcFgKyLmZJ956LYBws2J+dIeWCKw9cTXPhyQN9Ky8+ZAAoACxGV
2lZFA4gKn2fQ1XmxqI1AbQ3CekD6819kR5LLU7m7Wc5P/dAVUwHY3+vZ5nbv0CO7O6l5s9UC
Kc2Jo5YPSjXnTkLAdc0Hz+Ys63su
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIDtTCCAp2gAwIBAgIQdrEgUnTwhYdGs/gjGvbCwDANBgkqhkiG9w0BAQsFADBtMQswCQYD
VQQGEwJDSDEQMA4GA1UEChMHV0lTZUtleTEiMCAGA1UECxMZT0lTVEUgRm91bmRhdGlvbiBF
bmRvcnNlZDEoMCYGA1UEAxMfT0lTVEUgV0lTZUtleSBHbG9iYWwgUm9vdCBHQiBDQTAeFw0x
NDEyMDExNTAwMzJaFw0zOTEyMDExNTEwMzFaMG0xCzAJBgNVBAYTAkNIMRAwDgYDVQQKEwdX
SVNlS2V5MSIwIAYDVQQLExlPSVNURSBGb3VuZGF0aW9uIEVuZG9yc2VkMSgwJgYDVQQDEx9P
SVNURSBXSVNlS2V5IEdsb2JhbCBSb290IEdCIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
MIIBCgKCAQEA2Be3HEokKtaXscriHvt9OO+Y9bI5mE4nuBFde9IllIiCFSZqGzG7qFshISvY
D06fWvGxWuR51jIjK+FTzJlFXHtPrby/h0oLS5daqPZI7H17Dc0hBt+eFf1Biki3IPShehtX
1F1Q/7pn2COZH8g/497/b1t3sWtuuMlk9+HKQUYOKXHQuSP8yYFfTvdv37+ErXNku7dCjmn2
1HYdfp2nuFeKUWdy19SouJVUQHMD9ur06/4oQnc/nSMbsrY9gBQHTC5P99UKFg29ZkM3fiND
ecNAhvVMKdqOmq0NpQSHiB6F4+lT1ZvIiwNjeOvgGUpuuy9rM2RYk61pv48b74JIxwIDAQAB
o1EwTzALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUNQ/INmNe4qPs
+TtmFc5RUuORmj0wEAYJKwYBBAGCNxUBBAMCAQAwDQYJKoZIhvcNAQELBQADggEBAEBM+4ey
mYGQfp3FsLAmzYh7KzKNbrghcViXfa43FK8+5/ea4n32cZiZBKpDdHij40lhPnOMTZTg+XHE
thYOU3gf1qKHLwI5gSk8rxWYITD+KJAAjNHhy/peyP34EEY7onhCkRd0VQreUGdNZtGn//3Z
wLWoo4rOZvUPQ82nK1d7Y0Zqqi5S2PTt4W2tKZB4SLrhI6qjiey1q5bAtEuiHZeeevJuQHHf
aPFlTc58Bd9TZaml8LGXBHAVRgOY1NK/VLSgWH1Sb9pWJmLU2NuJMW8c8CLC02IcNc1MaRVU
GpCY3useX8p3x8uOPUNpnJpY0CQ73xtAln41rYHHTnG6iBM=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDcjCCAlqgAwIBAgIUPopdB+xV0jLVt+O2XwHrLdzk1uQwDQYJKoZIhvcNAQELBQAwUTEL
MAkGA1UEBhMCUEwxKDAmBgNVBAoMH0tyYWpvd2EgSXpiYSBSb3psaWN6ZW5pb3dhIFMuQS4x
GDAWBgNVBAMMD1NaQUZJUiBST09UIENBMjAeFw0xNTEwMTkwNzQzMzBaFw0zNTEwMTkwNzQz
MzBaMFExCzAJBgNVBAYTAlBMMSgwJgYDVQQKDB9LcmFqb3dhIEl6YmEgUm96bGljemVuaW93
YSBTLkEuMRgwFgYDVQQDDA9TWkFGSVIgUk9PVCBDQTIwggEiMA0GCSqGSIb3DQEBAQUAA4IB
DwAwggEKAoIBAQC3vD5QqEvNQLXOYeeWyrSh2gwisPq1e3YAd4wLz32ohswmUeQgPYUM1ljj
5/QqGJ3a0a4m7utT3PSQ1hNKDJA8w/Ta0o4NkjrcsbH/ON7Dui1fgLkCvUqdGw+0w8LBZwPd
3BucPbOw3gAeqDRHu5rr/gsUvTaE2g0gv/pby6kWIK05YO4vdbbnl5z5Pv1+TW9NL++IDWr6
3fE9biCloBK0TXC5ztdyO4mTp4CEHCdJckm1/zuVnsHMyAHs6A6KCpbns6aH5db5BSsNl0Bw
PLqsdVqc1U2dAgrSS5tmS0YHF2Wtn2yIANwiieDhZNRnvDF5YTy7ykHNXGoAyDw4jlivAgMB
AAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBQuFqlK
GLXLzPVvUPMjX/hd56zwyDANBgkqhkiG9w0BAQsFAAOCAQEAtXP4A9xZWx126aMqe5Aosk3A
M0+qmrHUuOQn/6mWmc5G4G18TKI4pAZw8PRBEew/R40/cof5O/2kbytTAOD/OblqBw7rHRz2
onKQy4I9EYKL0rufKq8h5mOGnXkZ7/e7DDWQw4rtTw/1zBLZpD67oPwglV9PJi8RI4NOdQcP
v5vRtB3pEAT+ymCPoky4rc/hkA/NrgrHXXu3UNLUYfrVFdvXn4dRVOul4+vJhaAlIDf7js4M
NIThPIGyd05DpYhfhmehPea0XGG2Ptv+tyjFogeutcrKjSoS75ftwjCkySp6+/NNIxuZMzSg
LvWpCz/UXeHPhJ/iGcJfitYgHuNztw==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIF0jCCA7qgAwIBAgIQIdbQSk8lD8kyN/yqXhKN6TANBgkqhkiG9w0BAQ0FADCBgDELMAkG
A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsT
HkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0
ZWQgTmV0d29yayBDQSAyMCIYDzIwMTExMDA2MDgzOTU2WhgPMjA0NjEwMDYwODM5NTZaMIGA
MQswCQYDVQQGEwJQTDEiMCAGA1UEChMZVW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUG
A1UECxMeQ2VydHVtIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MSQwIgYDVQQDExtDZXJ0dW0g
VHJ1c3RlZCBOZXR3b3JrIENBIDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC9
+Xj45tWADGSdhhuWZGc/IjoedQF97/tcZ4zJzFxrqZHmuULlIEub2pt7uZld2ZuAS9eEQCsn
0+i6MLs+CRqnSZXvK0AkwpfHp+6bJe+oCgCXhVqqndwpyeI1B+twTUrWwbNWuKFBOJvR+zF/
j+Bf4bE/D44WSWDXBo0Y+aomEKsq09DRZ40bRr5HMNUuctHFY9rnY3lEfktjJImGLjQ/KUxS
iyqnwOKRKIm5wFv5HdnnJ63/mgKXwcZQkpsCLL2puTRZCr+ESv/f/rOf69me4Jgj7KZrdxYq
28ytOxykh9xGc14ZYmhFV+SQgkK7QtbwYeDBoz1mo130GO6IyY0XRSmZMnUCMe4pJshrAua1
YkV/NxVaI2iJ1D7eTiew8EAMvE0Xy02isx7QBlrd9pPPV3WZ9fqGGmd4s7+W/jTcvedSVuWz
5XV710GRBdxdaeOVDUO5/IOWOZV7bIBaTxNyxtd9KXpEulKkKtVBRgkg/iKgtlswjbyJDNXX
cPiHUv3a76xRLgezTv7QCdpw75j6VuZt27VXS9zlLCUVyJ4ueE742pyehizKV/Ma5ciSixqC
lnrDvFASadgOWkaLOusm+iPJtrCBvkIApPjW/jAux9JG9uWOdf3yzLnQh1vMBhBgu4M1t15n
3kfsmUjxpKEV/q2MYo45VU85FrmxY53/twIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0G
A1UdDgQWBBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcN
AQENBQADggIBAHGlDs7k6b8/ONWJWsQCYftMxRQXLYtPU2sQF/xlhMcQSZDe28cmk4gmb3DW
Al45oPePq5a1pRNcgRRtDoGCERuKTsZPpd1iHkTfCVn0W3cLN+mLIMb4Ck4uWBzrM9DPhmDJ
2vuAL55MYIR4PSFk1vtBHxgP58l1cb29XN40hz5BsA72udY/CROWFC/emh1auVbONTqwX3BN
XuMp8SMoclm2q8KMZiYcdywmdjWLKKdpoPk79SPdhRB0yZADVpHnr7pH1BKXESLjokmUbOe3
lEu6LaTaM4tMpkT/WjzGHWTYtTHkpjx6qFcL2+1hGsvxznN3Y6SHb0xRONbkX8eftoEq5IVI
eVheO/jbAoJnwTnbw3RLPTYe+SmTiGhbqEQZIfCn6IENLOiTNrQ3ssqwGyZ6miUfmpqAnksq
P/ujmv5zMnHCnsZy4YpoJ/HkD7TETKVhk/iXEAcqMCWpuchxuO9ozC1+9eB+D4Kob7a6bIND
d82Kkhehnlt4Fj1F4jNy3eFmypnTycUm/Q1oBEauttmbjL4ZvrHG8hnjXALKLNhvSgfZyTXa
QHXyxKcZb55CEJh15pWLYLztxRLXis7VmFxWlgPF7ncGNf/P5O4/E2Hu29othfDNrp2yGAlF
w5Khchf8R7agCyzxxN5DaAhqXzvwdmP7zAYspsbiDrW5viSP
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIGCzCCA/OgAwIBAgIBADANBgkqhkiG9w0BAQsFADCBpjELMAkGA1UEBhMCR1IxDzANBgNV
BAcTBkF0aGVuczFEMEIGA1UEChM7SGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2VhcmNoIElu
c3RpdHV0aW9ucyBDZXJ0LiBBdXRob3JpdHkxQDA+BgNVBAMTN0hlbGxlbmljIEFjYWRlbWlj
IGFuZCBSZXNlYXJjaCBJbnN0aXR1dGlvbnMgUm9vdENBIDIwMTUwHhcNMTUwNzA3MTAxMTIx
WhcNNDAwNjMwMTAxMTIxWjCBpjELMAkGA1UEBhMCR1IxDzANBgNVBAcTBkF0aGVuczFEMEIG
A1UEChM7SGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2VhcmNoIEluc3RpdHV0aW9ucyBDZXJ0
LiBBdXRob3JpdHkxQDA+BgNVBAMTN0hlbGxlbmljIEFjYWRlbWljIGFuZCBSZXNlYXJjaCBJ
bnN0aXR1dGlvbnMgUm9vdENBIDIwMTUwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
AQDC+Kk/G4n8PDwEXT2QNrCROnk8ZlrvbTkBSRq0t89/TSNTt5AA4xMqKKYx8ZEA4yjsriFB
zh/a/X0SWwGDD7mwX5nh8hKDgE0GPt+sr+ehiGsxr/CL0BgzuNtFajT0AoAkKAoCFZVedioN
mToUW/bLy1O8E00BiDeUJRtCvCLYjqOWXjrZMts+6PAQZe104S+nfK8nNLspfZu2zwnI5dMK
/IhlZXQK3HMcXM1AsRzUtoSMTFDPaI6oWa7CJ06CojXdFPQf/7J31Ycvqm59JCfnxssm5uX+
Zwdj2EUN3TpZZTlYepKZcj2chF6IIbjV9Cz82XBST3i4vTwri5WY9bPRaM8gFH5MXF/ni+X1
NYEZN9cRCLdmvtNKzoNXADrDgfgXy5I2XdGj2HUb4Ysn6npIQf1FGQatJ5lOwXBH3bWfgVMS
5bGMSF0xQxfjjMZ6Y5ZLKTBOhE5iGV48zpeQpX8B653g+IuJ3SWYPZK2fu/Z8VFRfS0myGlZ
YeCsargqNhEEelC9MoS+L9xy1dcdFkfkR2YgP/SWxa+OAXqlD3pk9Q0Yh9muiNX6hME6wGko
LfINaFGq46V3xqSQDqE3izEjR8EJCOtu93ib14L8hCCZSRm2Ekax+0VVFqmjZaycBw/qa9wf
LgZy7IaIEuQt218FL+TwA9MmM+eAws1CoRc0CwIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/
MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUcRVnyMjJvXVdctA4GGqd83EkVAswDQYJKoZI
hvcNAQELBQADggIBAHW7bVRLqhBYRjTyYtcWNl0IXtVsyIe9tC5G8jH4fOpCtZMWVdyhDBKg
2mF+D1hYc2Ryx+hFjtyp8iY/xnmMsVMIM4GwVhO+5lFc2JsKT0ucVlMC6U/2DWDqTUJV6Hwb
ISHTGzrMd/K4kPFox/la/vot9L/J9UUbzjgQKjeKeaO04wlshYaT/4mWJ3iBj2fjRnRUjtkN
aeJK9E10A/+yd+2VZ5fkscWrv2oj6NSU4kQoYsRL4vDY4ilrGnB+JGGTe08DMiUNRSQrlrRG
ar9KC/eaj8GsGsVn82800vpzY4zvFrCopEYq+OsS7HK07/grfoxSwIuEVPkvPuNVqNxmsdnh
X9izjFk0WaSrT2y7HxjbdavYy5LNlDhhDgcGH0tGEPEVvo2FXDtKK4F5D7Rpn0lQl033DlZd
wJVqwjbDG2jJ9SrcR5q+ss7FJej6A7na+RZukYT1HCjI/CbM1xyQVqdfbzoEvM14iQuODy+j
qk+iGxI9FghAD/FGTNeqewjBCvVtJ94Cj8rDtSvK6evIIVM4pcw72Hc3MKJP2W/R8kCtQXoX
xdZKNYm3QdV8hn9VTYNKpXMgwDqvkPGaJI7ZjnHKe7iG2rKPmT4dEw0SEe7Uq/DpFXYC5ODf
qiAeW2GFZECpkJcNrVPSWh2HagCXZWK0vm9qp/UsQu0yrbYhnr68
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIICwzCCAkqgAwIBAgIBADAKBggqhkjOPQQDAjCBqjELMAkGA1UEBhMCR1IxDzANBgNVBAcT
BkF0aGVuczFEMEIGA1UEChM7SGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2VhcmNoIEluc3Rp
dHV0aW9ucyBDZXJ0LiBBdXRob3JpdHkxRDBCBgNVBAMTO0hlbGxlbmljIEFjYWRlbWljIGFu
ZCBSZXNlYXJjaCBJbnN0aXR1dGlvbnMgRUNDIFJvb3RDQSAyMDE1MB4XDTE1MDcwNzEwMzcx
MloXDTQwMDYzMDEwMzcxMlowgaoxCzAJBgNVBAYTAkdSMQ8wDQYDVQQHEwZBdGhlbnMxRDBC
BgNVBAoTO0hlbGxlbmljIEFjYWRlbWljIGFuZCBSZXNlYXJjaCBJbnN0aXR1dGlvbnMgQ2Vy
dC4gQXV0aG9yaXR5MUQwQgYDVQQDEztIZWxsZW5pYyBBY2FkZW1pYyBhbmQgUmVzZWFyY2gg
SW5zdGl0dXRpb25zIEVDQyBSb290Q0EgMjAxNTB2MBAGByqGSM49AgEGBSuBBAAiA2IABJKg
QehLgoRc4vgxEZmGZE4JJS+dQS8KrjVPdJWyUWRrjWvmP3CV8AVER6ZyOFB2lQJajq4onvkt
TpnvLEhvTCUp6NFxW98dwXU3tNf6e3pCnGoKVlp8aQuqgAkkbH7BRqNCMEAwDwYDVR0TAQH/
BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFLQiC4KZJAEOnLvkDv2/+5cgk5kq
MAoGCCqGSM49BAMCA2cAMGQCMGfOFmI4oqxiRaeplSTAGiecMjvAwNW6qef4BENThe5SId6d
9SWDPp5YSy/XZxMOIQIwBeF1Ad5o7SofTUwJCA3sS61kFyjndc5FZXIhF8siQQ6ME5g4mlRt
m8rifOoCWCKR
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAwTzELMAkG
A1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2VhcmNoIEdyb3VwMRUw
EwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4WhcNMzUwNjA0MTEwNDM4WjBP
MQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3Jv
dXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
ggIBAK3oJHP0FDfzm54rVygch77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj
/RQSa78f0uoxmyF+0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7i
S4+3mX6UA5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyHB5T0Y3Hs
LuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UCB5iPNgiV5+I3lg02
dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUvKBds0pjBqAlkd25HN7rOrFle
aJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWnOlFuhjuefXKnEgV4We0+UXgVCwOPjdAv
BbI+e0ocS3MFEvzG6uBQE3xDk3SzynTnjh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymC
zLq9gwQbooMDQaHWBfEbwrbwqHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC
1CLQJ13hef4Y53CIrU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIB
BjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZLubhzEFnT
IZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ3BebYhtF8GaV0nxv
wuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KKNFtY2PwByVS5uCbMiogziUwt
hDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5ORAzI4JMPJ+GslWYHb4phowim57iaztX
OoJwTdwJx4nLCgdNbOhdjsnvzqvHu7UrTkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIu
vtd7u+Nxe5AW0wdeRlN8NwdCjNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1N
bdWhscdCb+ZAJzVcoyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4k
qKOJ2qxq4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57demyPxgcY
xn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIPXZONMGc2yAYdGsdUhGkHMA0GCSqGSIb3DQEBCwUAMDsxCzAJBgNV
BAYTAkVTMREwDwYDVQQKDAhGTk1ULVJDTTEZMBcGA1UECwwQQUMgUkFJWiBGTk1ULVJDTTAe
Fw0wODEwMjkxNTU5NTZaFw0zMDAxMDEwMDAwMDBaMDsxCzAJBgNVBAYTAkVTMREwDwYDVQQK
DAhGTk1ULVJDTTEZMBcGA1UECwwQQUMgUkFJWiBGTk1ULVJDTTCCAiIwDQYJKoZIhvcNAQEB
BQADggIPADCCAgoCggIBALpxgHpMhm5/yBNtwMZ9HACXjywMI7sQmkCpGreHiPibVmr75nuO
i5KOpyVdWRHbNi63URcfqQgfBBckWKo3Shjf5TnUV/3XwSyRAZHiItQDwFj8d0fsjz50Q7qs
NI1NOHZnjrDIbzAzWHFctPVrbtQBULgTfmxKo0nRIBnuvMApGGWn3v7v3QqQIecaZ5JCEJhf
TzC8PhxFtBDXaEAUwED653cXeuYLj2VbPNmaUtu1vZ5Gzz3rkQUCwJaydkxNEJY7kvqcfw+Z
374jNUUeAlz+taibmSXaXvMiwzn15Cou08YfxGyqxRxqAQVKL9LFwag0Jl1mpdICIfkYtwb1
TplvqKtMUejPUBjFd8g5CSxJkjKZqLsXF3mwWsXmo8RZZUc1g16p6DULmbvkzSDGm0oGObVo
/CK67lWMK07q87Hj/LaZmtVC+nFNCM+HHmpxffnTtOmlcYF7wk5HlqX2doWjKI/pgG6BU6Vt
X7hI+cL5NqYuSf+4lsKMB7ObiFj86xsc3i1w4peSMKGJ47xVqCfWS+2QrYv6YyVZLag13cqX
M7zlzced0ezvXg5KkAYmY6252TUtB7p2ZSysV4999AeU14ECll2jB0nVetBX+RvnU0Z1qrB5
QstocQjpYL05ac70r8NWQMetUqIJ5G+GR4of6ygnXYMgrwTJbFaai0b1AgMBAAGjgYMwgYAw
DwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFPd9xf3E6Jobd2Sn
9R2gzL+HYJptMD4GA1UdIAQ3MDUwMwYEVR0gADArMCkGCCsGAQUFBwIBFh1odHRwOi8vd3d3
LmNlcnQuZm5tdC5lcy9kcGNzLzANBgkqhkiG9w0BAQsFAAOCAgEAB5BK3/MjTvDDnFFlm5wi
oooMhfNzKWtN/gHiqQxjAb8EZ6WdmF/9ARP67Jpi6Yb+tmLSbkyU+8B1RXxlDPiyN8+sD8+N
b/kZ94/sHvJwnvDKuO+3/3Y3dlv2bojzr2IyIpMNOmqOFGYMLVN0V2Ue1bLdI4E7pWYjJ2cJ
j+F3qkPNZVEI7VFY/uY5+ctHhKQV8Xa7pO6kO8Rf77IzlhEYt8llvhjho6Tc+hj507wTmzl6
NLrTQfv6MooqtyuGC2mDOL7Nii4LcK2NJpLuHvUBKwrZ1pebbuCoGRw6IYsMHkCtA+fdZn71
uSANA+iW+YJF1DngoABd15jmfZ5nc8OaKveri6E6FO80vFIOiZiaBECEHX5FaZNXzuvO+FB8
TxxuBEOb+dY7Ixjp6o7RTUaN8Tvkasq6+yO3m/qZASlaWFot4/nUbQ4mrcFuNLwy+AwF+mWj
2zs3gyLp1txyM/1d8iC9djwj2ij3+RvrWWTV3F9yfiD8zYm1kGdNYno/Tq0dwzn+evQoFt9B
9kiABdcPUXmsEKvU7ANm5mqwujGSQkBqvjrTcuFqN1W8rB2Vt2lh8kORdOag0wokRqEIr9ba
RRmW1FMdW4R58MD3R++Lj8UGrp1MYp3/RgT408m2ECVAdf4WqslKYIYvuu8wd+RU4riEmViA
qhOLUTpPSPaLtrM=
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsFADA5MQsw
CQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6b24gUm9vdCBDQSAx
MB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTELMAkGA1UEBhMCVVMxDzANBgNV
BAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJvb3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEB
BQADggEPADCCAQoCggEBALJ4gHHKeNXjca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOg
Q3pOsqTQNroBvo3bSMgHFzZM9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9
tBb6dNqcmzU5L/qwIFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAw
hmahRWa6VOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L
93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQmjgSubJrI
qg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAYYwHQYDVR0OBBYE
FIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUAA4IBAQCY8jdaQZChGsV2USgg
NiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDIU5PMCCjjmCXPI6T53iHTfIUJrU6adTrC
C2qJeHZERxhlbI1Bjjt/msv0tadQ1wUsN+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V
8viTO96LXFvKWlJbYK8U90vvo/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJc
JmApzyMZFo6IQ6XU5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeX
eGADbkpyrqXRfboQnoZsG4q5WTP468SQvvG5
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFQTCCAymgAwIBAgITBmyf0pY1hp8KD+WGePhbJruKNzANBgkqhkiG9w0BAQwFADA5MQsw
CQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6b24gUm9vdCBDQSAy
MB4XDTE1MDUyNjAwMDAwMFoXDTQwMDUyNjAwMDAwMFowOTELMAkGA1UEBhMCVVMxDzANBgNV
BAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJvb3QgQ0EgMjCCAiIwDQYJKoZIhvcNAQEB
BQADggIPADCCAgoCggIBAK2Wny2cSkxKgXlRmeyKy2tgURO8TW0G/LAIjd0ZEGrHJgw12MBv
IITplLGbhQPDW9tK6Mj4kHbZW0/jTOgGNk3Mmqw9DJArktQGGWCsN0R5hYGCrVo34A3MnaZM
UnbqQ523BNFQ9lXg1dKmSYXpN+nKfq5clU1Imj+uIFptiJXZNLhSGkOQsL9sBbm2eLfq0OQ6
PBJTYv9K8nu+NQWpEjTj82R0Yiw9AElaKP4yRLuH3WUnAnE72kr3H9rN9yFVkE8P7K6C4Z9r
2UXTu/Bfh+08LDmG2j/e7HJV63mjrdvdfLC6HM783k81ds8P+HgfajZRRidhW+mez/CiVX18
JYpvL7TFz4QuK/0NURBs+18bvBt+xa47mAExkv8LV/SasrlX6avvDXbR8O70zoan4G7ptGmh
32n2M8ZpLpcTnqWHsFcQgTfJU7O7f/aS0ZzQGPSSbtqDT6ZjmUyl+17vIWR6IF9sZIUVyzfp
YgwLKhbcAS4y2j5L9Z469hdAlO+ekQiG+r5jqFoz7Mt0Q5X5bGlSNscpb/xVA1wf+5+9R+vn
SUeVC06JIglJ4PVhHvG/LopyboBZ/1c6+XUyo05f7O0oYtlNc/LMgRdg7c3r3NunysV+Ar3y
VAhU/bQtCSwXVEqY0VThUWcI0u1ufm8/0i2BWSlmy5A5lREedCf+3euvAgMBAAGjQjBAMA8G
A1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGGMB0GA1UdDgQWBBSwDPBMMPQFWAJI/TPl
Uq9LhONmUjANBgkqhkiG9w0BAQwFAAOCAgEAqqiAjw54o+Ci1M3m9Zh6O+oAA7CXDpO8Wqj2
LIxyh6mx/H9z/WNxeKWHWc8w4Q0QshNabYL1auaAn6AFC2jkR2vHat+2/XcycuUY+gn0oJMs
XdKMdYV2ZZAMA3m3MSNjrXiDCYZohMr/+c8mmpJ5581LxedhpxfL86kSk5Nrp+gvU5LEYFiw
zAJRGFuFjWJZY7attN6a+yb3ACfAXVU3dJnJUH/jWS5E4ywl7uxMMne0nxrpS10gxdr9HIcW
xkPo1LsmmkVwXqkLN1PiRnsn/eBG8om3zEK2yygmbtmlyTrIQRNg91CMFa6ybRoVGld45pIq
2WWQgj9sAq+uEjonljYE1x2igGOpm/HlurR8FLBOybEfdF849lHqm/osohHUqS0nGkWxr7JO
cQ3AWEbWaQbLU8uz/mtBzUF+fUwPfHJ5elnNXkoOrJupmHN5fLT0zLm4BwyydFy4x2+IoZCn
9Kr5v2c69BoVYh63n749sSmvZ6ES8lgQGVMDMBu4Gon2nL2XA46jCfMdiyHxtN/kHNGfZQIG
6lzWE7OE76KlXIx3KadowGuuQNKotOrN8I1LOJwZmhsoVLiJkO/KdYE+HvJkJMcYr07/R54H
9jVlpNMKVv/1F2Rs76giJUmTtt8AF9pYfl3uxRuw0dFfIRDH+fO6AgonB8Xx1sfT4PsJYGw=
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIBtjCCAVugAwIBAgITBmyf1XSXNmY/Owua2eiedgPySjAKBggqhkjOPQQDAjA5MQswCQYD
VQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6b24gUm9vdCBDQSAzMB4X
DTE1MDUyNjAwMDAwMFoXDTQwMDUyNjAwMDAwMFowOTELMAkGA1UEBhMCVVMxDzANBgNVBAoT
BkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJvb3QgQ0EgMzBZMBMGByqGSM49AgEGCCqGSM49
AwEHA0IABCmXp8ZBf8ANm+gBG1bG8lKlui2yEujSLtf6ycXYqm0fc4E7O5hrOXwzpcVOho6A
F2hiRVd9RFgdszflZwjrZt6jQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGG
MB0GA1UdDgQWBBSrttvXBp43rDCGB5Fwx5zEGbF4wDAKBggqhkjOPQQDAgNJADBGAiEA4IWS
oxe3jfkrBqWTrBqYaGFy+uGh0PsceGCmQ5nFuMQCIQCcAu/xlJyzlvnrxir4tiz+OpAUFteM
YyRIHN8wfdVoOw==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIB8jCCAXigAwIBAgITBmyf18G7EEwpQ+Vxe3ssyBrBDjAKBggqhkjOPQQDAzA5MQswCQYD
VQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6b24gUm9vdCBDQSA0MB4X
DTE1MDUyNjAwMDAwMFoXDTQwMDUyNjAwMDAwMFowOTELMAkGA1UEBhMCVVMxDzANBgNVBAoT
BkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJvb3QgQ0EgNDB2MBAGByqGSM49AgEGBSuBBAAi
A2IABNKrijdPo1MN/sGKe0uoe0ZLY7Bi9i0b2whxIdIA6GO9mif78DluXeo9pcmBqqNbIJhF
XRbb/egQbeOc4OO9X4Ri83BkM6DLJC9wuoihKqB1+IGuYgbEgds5bimwHvouXKNCMEAwDwYD
VR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAYYwHQYDVR0OBBYEFNPsxzplbszh2naaVvuc
84ZtV+WBMAoGCCqGSM49BAMDA2gAMGUCMDqLIfG9fhGt0O9Yli/W651+kI0rz2ZVwyzjKKlw
CkcO8DdZEv8tmZQoTipPNU0zWgIxAOp1AE47xDqUEpHJWEadIRNyp4iciuRMStuW1KyLa2tJ
ElMzrdfkviT8tQp21KW8EA==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIEYzCCA0ugAwIBAgIBATANBgkqhkiG9w0BAQsFADCB0jELMAkGA1UEBhMCVFIxGDAWBgNV
BAcTD0dlYnplIC0gS29jYWVsaTFCMEAGA1UEChM5VHVya2l5ZSBCaWxpbXNlbCB2ZSBUZWtu
b2xvamlrIEFyYXN0aXJtYSBLdXJ1bXUgLSBUVUJJVEFLMS0wKwYDVQQLEyRLYW11IFNlcnRp
ZmlrYXN5b24gTWVya2V6aSAtIEthbXUgU00xNjA0BgNVBAMTLVRVQklUQUsgS2FtdSBTTSBT
U0wgS29rIFNlcnRpZmlrYXNpIC0gU3VydW0gMTAeFw0xMzExMjUwODI1NTVaFw00MzEwMjUw
ODI1NTVaMIHSMQswCQYDVQQGEwJUUjEYMBYGA1UEBxMPR2ViemUgLSBLb2NhZWxpMUIwQAYD
VQQKEzlUdXJraXllIEJpbGltc2VsIHZlIFRla25vbG9qaWsgQXJhc3Rpcm1hIEt1cnVtdSAt
IFRVQklUQUsxLTArBgNVBAsTJEthbXUgU2VydGlmaWthc3lvbiBNZXJrZXppIC0gS2FtdSBT
TTE2MDQGA1UEAxMtVFVCSVRBSyBLYW11IFNNIFNTTCBLb2sgU2VydGlmaWthc2kgLSBTdXJ1
bSAxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAr3UwM6q7a9OZLBI3hNmNe5eA
027n/5tQlT6QlVZC1xl8JoSNkvoBHToP4mQ4t4y86Ij5iySrLqP1N+RAjhgleYN1Hzv/bKjF
xlb4tO2KRKOrbEz8HdDc72i9z+SqzvBV96I01INrN3wcwv61A+xXzry0tcXtAA9TNypN9E8M
g/uGz8v+jE69h/mniyFXnHrfA2eJLJ2XYacQuFWQfw4tJzh03+f92k4S400VIgLI4OD8D62K
18lUUMw7D8oWgITQUVbDjlZ/iSIzL+aFCr2lqBs23tPcLG07xxO9WSMs5uWk99gL7eqQQESo
lbuT1dCANLZGeA4fAJNG4e7p+exPFwIDAQABo0IwQDAdBgNVHQ4EFgQUZT/HiobGPN08VFw1
+DrtUgxHV8gwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEL
BQADggEBACo/4fEyjq7hmFxLXs9rHmoJ0iKpEsdeV31zVmSAhHqT5Am5EM2fKifhAHe+SMg1
qIGf5LgsyX8OsNJLN13qudULXjS99HMpw+0mFZx+CFOKWI3QSyjfwbPfIPP54+M638yclNhO
T8NrF7f3cuitZjO1JVOr4PhMqZ398g26rrnZqsZr+ZO7rqu4lzwDGrpDxpa5RXI4s6ehlj2R
e37AIVNMh+3yC1SVUZPVIqUNivGTDj5UDrDYyU7c8jEyVupk+eq1nRZmQnLzf9OxMUP8pI4X
8W0jq5Rm+K37DwhuJi1/FwcJsoz7UMCflo3Ptv0AnVoUmr8CRPXBwp8iXqIPoeM=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIFiDCCA3CgAwIBAgIIfQmX/vBH6nowDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCQ04x
MjAwBgNVBAoMKUdVQU5HIERPTkcgQ0VSVElGSUNBVEUgQVVUSE9SSVRZIENPLixMVEQuMR8w
HQYDVQQDDBZHRENBIFRydXN0QVVUSCBSNSBST09UMB4XDTE0MTEyNjA1MTMxNVoXDTQwMTIz
MTE1NTk1OVowYjELMAkGA1UEBhMCQ04xMjAwBgNVBAoMKUdVQU5HIERPTkcgQ0VSVElGSUNB
VEUgQVVUSE9SSVRZIENPLixMVEQuMR8wHQYDVQQDDBZHRENBIFRydXN0QVVUSCBSNSBST09U
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA2aMW8Mh0dHeb7zMNOwZ+Vfy1YI92
hhJCfVZmPoiC7XJjDp6L3TQsAlFRwxn9WVSEyfFrs0yw6ehGXTjGoqcuEVe6ghWinI9tsJlK
CvLriXBjTnnEt1u9ol2x8kECK62pOqPseQrsXzrj/e+APK00mxqriCZ7VqKChh/rNYmDf1+u
KU49tm7srsHwJ5uu4/Ts765/94Y9cnrrpftZTqfrlYwiOXnhLQiPzLyRuEH3FMEjqcOtmkVE
s7LXLM3GKeJQEK5cy4KOFxg2fZfmiJqwTTQJ9Cy5WmYqsBebnh52nUpmMUHfP/vFBu8btn4a
Rjb3ZGM74zkYI+dndRTVdVeSN72+ahsmUPI2JgaQxXABZG12ZuGR224HwGGALrIuL4xwp9E7
PLOR5G62xDtw8mySlwnNR30YwPO7ng/Wi64HtloPzgsMR6flPri9fcebNaBhlzpBdRfMK5Z3
KpIhHtmVdiBnaM8Nvd/WHwlqmuLMc3GkL30SgLdTMEZeS1SZD2fJpcjyIMGC7J0R38IC+xo7
0e0gmu9lZJIQDSri3nDxGGeCjGHeuLzRL5z7D9Ar7Rt2ueQ5Vfj4oR24qoAATILnsn8JuLww
oC8N9VKejveSswoAHQBUlwbgsQfZxw9cZX08bVlX5O2ljelAU58VS6Bx9hoh49pwBiFYFIeF
d3mqgnkCAwEAAaNCMEAwHQYDVR0OBBYEFOLJQJ9NzuiaoXzPDj9lxSmIahlRMA8GA1UdEwEB
/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4ICAQDRSVfgp8xoWLoB
DysZzY2wYUWsEe1jUGn4H3++Fo/9nesLqjJHdtJnJO29fDMylyrHBYZmDRd9FBUb1Ov9H5r2
XpdptxolpAqzkT9fNqyL7FeoPueBihhXOYV0GkLH6VsTX4/5COmSdI31R9KrO9b7eGZONn35
6ZLpBN79SWP8bfsUcZNnL0dKt7n/HipzcEYwv1ryL3ml4Y0M2fmyYzeMN2WFcGpcWwlyua1j
PLHd+PwyvzeG5LuOmCd+uh8W4XAR8gPfJWIyJyYYMoSf/wA6E7qaTfRPuBRwIrHKK5DOKcFw
9C+df/KQHtZa37dG/OaG+svgIHZ6uqbL9XzeYqWxi+7egmaKTjowHz+Ay60nugxe19CxVsp3
cbK1daFQqUBDF8Io2c9Si1vIY9RCPqAzekYu9wogRlR+ak8x8YF+QnQ4ZXMn7sZ8uI7XpTrX
mKGcjBBV09tL7ECQ8s1uV9JiDnxXk7Gnbc2dg7sq5+W2O3FYrf3RRbxake5TFW/TRQl1brqQ
XR4EzzffHqhmsYzmIGrv/EhOdJhCrylvLmrH+33RZjEizIYAfmaDDEL0vTSSwxrqT8p+ck0L
cIymSLumoRT2+1hEmRSuqguTaaApJUqlyyvdimYHFngVV3Eb7PVHhPOeMTd61X8kreS8/f3M
boPoDKi3QWwH3b08hpcv0g==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIF3TCCA8WgAwIBAgIIeyyb0xaAMpkwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMx
DjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMRgwFgYDVQQKDA9TU0wgQ29ycG9y
YXRpb24xMTAvBgNVBAMMKFNTTC5jb20gUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSBS
U0EwHhcNMTYwMjEyMTczOTM5WhcNNDEwMjEyMTczOTM5WjB8MQswCQYDVQQGEwJVUzEOMAwG
A1UECAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlv
bjExMC8GA1UEAwwoU1NMLmNvbSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IFJTQTCC
AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAPkP3aMrfcvQKv7sZ4Wm5y4bunfh4/Wv
pOz6Sl2RxFdHaxh3a3by/ZPkPQ/CFp4LZsNWlJ4Xg4XOVu/yFv0AYvUiCVToZRdOQbngT0aX
qhvIuG5iXmmxX9sqAn78bMrzQdjt0Oj8P2FI7bADFB0QDksZ4LtO7IZl/zbzXmcCC52GVWH9
ejjt/uIZALdvoVBidXQ8oPrIJZK0bnoix/geoeOy3ZExqysdBP+lSgQ36YWkMyv94tZVNHwZ
pEpox7Ko07fKoZOI68GXvIz5HdkihCR0xwQ9aqkpk8zruFvh/l8lqjRYyMEjVJ0bmBHDOJx+
PYZspQ9AhnwC9FwCTyjLrnGfDzrIM/4RJTXq/LrFYD3ZfBjVsqnTdXgDciLKOsMf7yzlLqn6
niy2UUb9rwPW6mBo6oUWNmuF6R7As93EJNyAKoFBbZQ+yODJgUEAnl6/f8UImKIYLEJAs/lv
OCdLToD0PYFH4Ih86hzOtXVcUS4cK38acijnALXRdMbX5J+tB5O2UzU1/Dfkw/ZdFr4hc96S
CvigY2q8lpJqPvi8ZVWb3vUNiSYE/CUapiVpy8JtynziWV+XrOvvLsi81xtZPCvM8hnIk2sn
YxnP/Okm+Mpxm3+T/jRnhE6Z6/yzeAkzcLpmpnbtG3PrGqUNxCITIJRWCk4sbE6x/c+cCbqi
M+2HAgMBAAGjYzBhMB0GA1UdDgQWBBTdBAkHovV6fVJTEpKV7jiAJQ2mWTAPBgNVHRMBAf8E
BTADAQH/MB8GA1UdIwQYMBaAFN0ECQei9Xp9UlMSkpXuOIAlDaZZMA4GA1UdDwEB/wQEAwIB
hjANBgkqhkiG9w0BAQsFAAOCAgEAIBgRlCn7Jp0cHh5wYfGVcpNxJK1ok1iOMq8bs3AD/CUr
dIWQPXhq9LmLpZc7tRiRux6n+UBbkflVma8eEdBcHadm47GUBwwyOabqG7B52B2ccETjit3E
+ZUfijhDPwGFpUenPUayvOUiaPd7nNgsPgohyC0zrL/FgZkxdMF1ccW+sfAjRfSda/wZY52j
vATGGAslu1OJD7OAUN5F7kR/q5R4ZJjT9ijdh9hwZXT7DrkT66cPYakylszeu+1jTBi7qUD3
oFRuIIhxdRjqerQ0cuAjJ3dctpDqhiVAq+8zD8ufgr6iIPv2tS0a5sKFsXQP+8hlAqRSAUfd
SSLBv9jra6x+3uxjMxW3IwiPxg+NQVrdjsW5j+VFP3jbutIbQLH+cU0/4IGiul607BXgk90I
H37hVZkLId6Tngr75qNJvTYw/ud3sqB1l7UtgYgXZSD32pAAn8lSzDLKNXz1PQ/YK9f1JmzJ
BjSWFupwWRoyeXkLtoh/D1JIPb9s2KJELtFOt3JY04kTlf5Eq/jXixtunLwsoFvVagCvXzfh
1foQC5ichucmj87w7G6KVwuA406ywKBjYZC6VWg3dGq2ktufoYYitmUnDuy2n0Jg5GfCtdpB
C8TTi2EbvPofkSvXRAdeuims2cXp71NIWuuA8ShYIc2wBlX7Jz9TkHCpBB5XJ7k=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIICjTCCAhSgAwIBAgIIdebfy8FoW6gwCgYIKoZIzj0EAwIwfDELMAkGA1UEBhMCVVMxDjAM
BgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMRgwFgYDVQQKDA9TU0wgQ29ycG9yYXRp
b24xMTAvBgNVBAMMKFNTTC5jb20gUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSBFQ0Mw
HhcNMTYwMjEyMTgxNDAzWhcNNDEwMjEyMTgxNDAzWjB8MQswCQYDVQQGEwJVUzEOMAwGA1UE
CAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjEx
MC8GA1UEAwwoU1NMLmNvbSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzB2MBAG
ByqGSM49AgEGBSuBBAAiA2IABEVuqVDEpiM2nl8ojRfLliJkP9x6jh3MCLOicSS6jkm5BBtH
llirLZXI7Z4INcgn64mMU1jrYor+8FsPazFSY0E7ic3s7LaNGdM0B9y7xgZ/wkWV7Mt/qCPg
CemB+vNH06NjMGEwHQYDVR0OBBYEFILRhXMw5zUE044CkvvlpNHEIejNMA8GA1UdEwEB/wQF
MAMBAf8wHwYDVR0jBBgwFoAUgtGFczDnNQTTjgKS++Wk0cQh6M0wDgYDVR0PAQH/BAQDAgGG
MAoGCCqGSM49BAMCA2cAMGQCMG/n61kRpGDPYbCWe+0F+S8Tkdzt5fxQaxFGRrMcIQBiu77D
5+jNB5n5DQtdcj7EqgIwH7y6C+IwJPt8bYBVCpk+gA0z5Wajs6O7pdWLjwkspl1+4vAHCGht
0nxpbl/f5Wpl
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIF6zCCA9OgAwIBAgIIVrYpzTS8ePYwDQYJKoZIhvcNAQELBQAwgYIxCzAJBgNVBAYTAlVT
MQ4wDAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjEYMBYGA1UECgwPU1NMIENvcnBv
cmF0aW9uMTcwNQYDVQQDDC5TU0wuY29tIEVWIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
dHkgUlNBIFIyMB4XDTE3MDUzMTE4MTQzN1oXDTQyMDUzMDE4MTQzN1owgYIxCzAJBgNVBAYT
AlVTMQ4wDAYDVQQIDAVUZXhhczEQMA4GA1UEBwwHSG91c3RvbjEYMBYGA1UECgwPU1NMIENv
cnBvcmF0aW9uMTcwNQYDVQQDDC5TU0wuY29tIEVWIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRo
b3JpdHkgUlNBIFIyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjzZlQOHWTcDX
tOlG2mvqM0fNTPl9fb69LT3w23jhhqXZuglXaO1XPqDQCEGD5yhBJB/jchXQARr7XnAjssuf
OePPxU7Gkm0mxnu7s9onnQqG6YE3Bf7wcXHswxzpY6IXFJ3vG2fThVUCAtZJycxa4bH3bzKf
ydQ7iEGonL3Lq9ttewkfokxykNorCPzPPFTOZw+oz12WGQvE43LrrdF9HSfvkusQv1vrO6/P
gN3B0pYEW3p+pKk8OHakYo6gOV7qd89dAFmPZiw+B6KjBSYRaZfqhbcPlgtLyEDhULouisv3
D5oi53+aNxPN8k0TayHRwMwi8qFG9kRpnMphNQcAb9ZhCBHqurj26bNg5U257J8UZslXWNvN
h2n4ioYSA0e/ZhN2rHd9NCSFg83XqpyQGp8hLH94t2S42Oim9HizVcuE0jLEeK6jj2HdzghT
reyI/BXkmg3mnxp3zkyPuBQVPWKchjgGAGYS5Fl2WlPAApiiECtoRHuOec4zSnaqW4EWG7WK
2NAAe15itAnWhmMOpgWVSbooi4iTsjQc2KRVbrcc0N6ZVTsj9CLg+SlmJuwgUHfbSguPvuUC
YHBBXtSuUDkiFCbLsjtzdFVHB3mBOagwE0TlBIqulhMlQg+5U8Sb/M3kHN48+qvWBkofZ6aY
MBzdLNvcGJVXZsb/XItW9XcCAwEAAaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAW
gBT5YLvU49U09rj1BoAlp3PbRmmonjAdBgNVHQ4EFgQU+WC71OPVNPa49QaAJadz20ZpqJ4w
DgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4ICAQBWs47LCp1Jjr+kxJG7ZhcFUZh1
++VQLHqe8RT6q9OKPv+RKY9ji9i0qVQBDb6Thi/5Sm3HXvVX+cpVHBK+Rw82xd9qt9t1wkcl
f7nxY/hoLVUE0fKNsKTPvDxeH3jnpaAgcLAExbf3cqfeIg29MyVGjGSSJuM+LmOW2puMPfgY
CdcDzH2GguDKBAdRUNf/ktUM79qGn5nX67evaOI5JpS6aLe/g9Pqemc9YmeuJeVy6OLk7K4S
9ksrPJ/psEDzOFSz/bdoyNrGj1E8svuR3Bznm53htw1yj+KkxKl4+esUrMZDBcJlOSgYAsOC
sp0FvmXtll9ldDz7CTUue5wT/RsPXcdtgTpWD8w74a8CLyKsRspGPKAcTNZEtF4uXBVmCeEm
Kf7GUmG6sXP/wwyc5WxqlD8UykAWlYTzWamsX0xhk23RO8yilQwipmdnRC652dKKQbNmC1r7
fSOl8hqw/96bg5Qu0T/fkreRrwU7ZcegbLHNYhLDkBvjJc40vG93drEQw/cFGsDWr3RiSBd3
kmmQYRzelYB0VI8YHMPzA9C/pEN1hlMYegouCRw2n5H9gooiS9EOUCXdywMMF8mDAAhONU2K
i+3wApRmLER/y5UnlhetCTCstnEXbosX9hwJ1C07mKVx01QT2WDz9UtmT/rx7iASjbSsV7FF
Y6GsdqnC+w==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIClDCCAhqgAwIBAgIILCmcWxbtBZUwCgYIKoZIzj0EAwIwfzELMAkGA1UEBhMCVVMxDjAM
BgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMRgwFgYDVQQKDA9TU0wgQ29ycG9yYXRp
b24xNDAyBgNVBAMMK1NTTC5jb20gRVYgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSBF
Q0MwHhcNMTYwMjEyMTgxNTIzWhcNNDEwMjEyMTgxNTIzWjB/MQswCQYDVQQGEwJVUzEOMAwG
A1UECAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlv
bjE0MDIGA1UEAwwrU1NMLmNvbSBFViBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVD
QzB2MBAGByqGSM49AgEGBSuBBAAiA2IABKoSR5CYG/vvw0AHgyBO8TCCogbR8pKGYfL2IWjK
AMTH6kMAVIbc/R/fALhBYlzccBYy3h+Z1MzFB8gIH2EWB1E9fVwHU+M1OIzfzZ/ZLg1Kthku
WnBaBu2+8KGwytAJKaNjMGEwHQYDVR0OBBYEFFvKXuXe0oGqzagtZFG22XKbl+ZPMA8GA1Ud
EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUW8pe5d7SgarNqC1kUbbZcpuX5k8wDgYDVR0PAQH/
BAQDAgGGMAoGCCqGSM49BAMCA2gAMGUCMQCK5kCJN+vp1RPZytRrJPOwPYdGWBrssd9v+1a6
cGvHOMzosYxPD/fxZ3YOg9AeUY8CMD32IygmTMZgh5Mmm7I1HrrW9zzRHM76JTymGoEVW/MS
D2zuZYrJh6j5B+BimoxcSg==
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/RVEwDQYJKoZIhvcNAQEMBQAwTDEgMB4GA1UE
CxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjYxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNV
BAMTCkdsb2JhbFNpZ24wHhcNMTQxMjEwMDAwMDAwWhcNMzQxMjEwMDAwMDAwWjBMMSAwHgYD
VQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEG
A1UEAxMKR2xvYmFsU2lnbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPK
ZvnsFMp7PPcNCPG0RQssgrRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTOURQh7Erd
G1rG1ofuTToVBu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShNUhqKGoC3GYEOfsSK
vGRMIRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++gmNQ0PAYid/kD3n16qIfKtJw
LnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbzlUoSB239jLKJz9CgYXfIWHSw1CM69106
yqLbnQneXUQtkPGBzVeS+n68UARjNN9rkxi+azayOeSsJDa38O+2HBNXk7besvjihbdzorg1
qkXy4J02oW9UivFyVm4uiMVRQkQVlO6jxTiWm05OWgtH8wY2SXcwvHE35absIQh1/OZhFj93
1dmRl4QKbNQCTXTAFO39OfuD8l4UoQSwC+n+7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0a
EYdwgQqomnUdnjqGBQCe24DWJfncBZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpY
T9NLCEnFlWQaYw55PfWzjMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsRtYQUigAZ
cIN5kZeR1BonvzceMgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMB
Af8EBTADAQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzWx/B/yGdToDAfBgNVHSMEGDAWgBSu
bAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG9w0BAQwFAAOCAgEAgyXt6NH9lVLNnsAEoJFp
5lzQhN7craJP6Ed41mWYqVuoPId8AorRbrcWc+ZfwFSY1XS+wc3iEZGtIxg93eFyRJa0lV7A
e46ZeBZDE1ZXs6KzO7V33EByrKPrmzU+sQghoefEQzd5Mr6155wsTLxDKZmOMNOsIeDjHfrY
BzN2VAAiKrlNIC5waNrlU/yDXNOd8v9EDERm8tLjvUYAGm0CuiVdjaExUd1URhxN25mW7xoc
BFymFe944Hn+Xds+qkxV/ZoVqW/hpvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54NMMl
+68KnyBr3TsTjxKM4kEaSHpzoHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA/iU3/gKbaKxC
XcPu9czc8FB10jZpnOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HHTOwY3WzvUy2MmeFe8nI+
z1TIvWfspA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsViVO6LAUP5MSeGbEYNNVMnbrt9x+v
JJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9x8jvOOJckvB595yEunQtYQEgfn7R8k8HWV+L
LUNS60YMlOH1Zkd5d9VUWx+tJDfLRVpOoERIyNiwmcUVhAn21klJwGW45hpxbqCo8YLoRT5s
1gLXCmeDBVrJpBA=
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICaTCCAe+gAwIBAgIQISpWDK7aDKtARb8roi066jAKBggqhkjOPQQDAzBtMQswCQYDVQQG
EwJDSDEQMA4GA1UEChMHV0lTZUtleTEiMCAGA1UECxMZT0lTVEUgRm91bmRhdGlvbiBFbmRv
cnNlZDEoMCYGA1UEAxMfT0lTVEUgV0lTZUtleSBHbG9iYWwgUm9vdCBHQyBDQTAeFw0xNzA1
MDkwOTQ4MzRaFw00MjA1MDkwOTU4MzNaMG0xCzAJBgNVBAYTAkNIMRAwDgYDVQQKEwdXSVNl
S2V5MSIwIAYDVQQLExlPSVNURSBGb3VuZGF0aW9uIEVuZG9yc2VkMSgwJgYDVQQDEx9PSVNU
RSBXSVNlS2V5IEdsb2JhbCBSb290IEdDIENBMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAETOlQ
wMYPchi82PG6s4nieUqjFqdrVCTbUf/q9Akkwwsin8tqJ4KBDdLArzHkdIJuyiXZjHWd8dvQ
mqJLIX4Wp2OQ0jnUsYd4XxiWD1AbNTcPasbc2RNNpI6QN+a9WzGRo1QwUjAOBgNVHQ8BAf8E
BAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUSIcUrOPDnpBgOtfKie7TrYy0UGYw
EAYJKwYBBAGCNxUBBAMCAQAwCgYIKoZIzj0EAwMDaAAwZQIwJsdpW9zV57LnyAyMjMPdeYwb
Y9XJUpROTYJKcx6ygISpJcBMWm1JKWB4E+J+SOtkAjEA2zQgMgj/mkkCtojeFK9dbJlxjRo/
i9fgojaGHAeCOnZT/cKi7e97sIBPWA9LUzm9
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIFRjCCAy6gAwIBAgIQXd+x2lqj7V2+WmUgZQOQ7zANBgkqhkiG9w0BAQsFADA9MQswCQYD
VQQGEwJDTjERMA8GA1UECgwIVW5pVHJ1c3QxGzAZBgNVBAMMElVDQSBHbG9iYWwgRzIgUm9v
dDAeFw0xNjAzMTEwMDAwMDBaFw00MDEyMzEwMDAwMDBaMD0xCzAJBgNVBAYTAkNOMREwDwYD
VQQKDAhVbmlUcnVzdDEbMBkGA1UEAwwSVUNBIEdsb2JhbCBHMiBSb290MIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxeYrb3zvJgUno4Ek2m/LAfmZmqkywiKHYUGRO8vDaBsG
xUypK8FnFyIdK+35KYmToni9kmugow2ifsqTs6bRjDXVdfkX9s9FxeV67HeToI8jrg4aA3++
1NDtLnurRiNb/yzmVHqUwCoV8MmNsHo7JOHXaOIxPAYzRrZUEaalLyJUKlgNAQLx+hVRZ2zA
+te2G3/RVogvGjqNO7uCEeBHANBSh6v7hn4PJGtAnTRnvI3HLYZveT6OqTwXS3+wmeOwcWDc
C/Vkw85DvG1xudLeJ1uK6NjGruFZfc8oLTW4lVYa8bJYS7cSN8h8s+1LgOGN+jIjtm+3SJUI
sUROhYw6AlQgL9+/V087OpAh18EmNVQg7Mc/R+zvWr9LesGtOxdQXGLYD0tK3Cv6brxzks3s
x1DoQZbXqX5t2Okdj4q1uViSukqSKwxW/YDrCPBeKW4bHAyvj5OJrdu9o54hyokZ7N+1wxrr
Fv54NkzWbtA+FxyQF2smuvt6L78RHBgOLXMDj6DlNaBa4kx1HXHhOThTeEDMg5PXCp6dW4+K
5OXgSORIskfNTip1KnvyIvbJvgmRlld6iIis7nCs+dwp4wwcOxJORNanTrAmyPPZGpeRaOrv
jUYG0lZFWJo8DA+DuAUlwznPO6Q0ibd5Ei9Hxeepl2n8pndntd978XplFeRhVmUCAwEAAaNC
MEAwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFIHEjMz15DD/
pQwIX4wVZyF0Ad/fMA0GCSqGSIb3DQEBCwUAA4ICAQATZSL1jiutROTL/7lo5sOASD0Ee/oj
L3rtNtqyzm325p7lX1iPyzcyochltq44PTUbPrw7tgTQvPlJ9Zv3hcU2tsu8+Mg51eRfB70V
VJd0ysrtT7q6ZHafgbiERUlMjW+i67HM0cOU2kTC5uLqGOiiHycFutfl1qnN3e92mI0ADs0b
+gO3joBYDic/UvuUospeZcnWhNq5NXHzJsBPd+aBJ9J3O5oUb3n09tDh05S60FdRvScFDcH9
yBIw7m+NESsIndTUv4BFFJqIRNow6rSn4+7vW4LVPtateJLbXDzz2K36uGt/xDYotgIVilQs
nLAXc47QN6MUPJiVAAwpBVueSUmxX8fjy88nZY41F7dXyDDZQVu5FLbowg+UMaeUmMxq67Xh
J/UQqAHojhJi6IjMtX9Gl8CbEGY4GjZGXyJoPd/JxhMnq1MGrKI8hgZlb7F+sSlEmqO6SWko
aY/X5V+tBIZkbxqgDMUIYs6Ao9Dz7GjevjPHF1t/gMRMTLGmhIrDO7gJzRSBuhjjVFc2/tsv
fEehOjPI+Vg7RE+xygKJBJYoaMVLuCaJu9YzL1DV/pqJuhgyklTGW+Cd+V7lDSKb9triyCGy
YiGqhkCyLmTTX8jjfhFnRR8F/uOi77Oos/N9j/gMHyIfLXC0uAE0djAA5SN4p1bXUB+K+wb1
whnw0A==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFWjCCA0KgAwIBAgIQT9Irj/VkyDOeTzRYZiNwYDANBgkqhkiG9w0BAQsFADBHMQswCQYD
VQQGEwJDTjERMA8GA1UECgwIVW5pVHJ1c3QxJTAjBgNVBAMMHFVDQSBFeHRlbmRlZCBWYWxp
ZGF0aW9uIFJvb3QwHhcNMTUwMzEzMDAwMDAwWhcNMzgxMjMxMDAwMDAwWjBHMQswCQYDVQQG
EwJDTjERMA8GA1UECgwIVW5pVHJ1c3QxJTAjBgNVBAMMHFVDQSBFeHRlbmRlZCBWYWxpZGF0
aW9uIFJvb3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCpCQcoEwKwmeBkqh5D
FnpzsZGgdT6o+uM4AHrsiWogD4vFsJszA1qGxliG1cGFu0/GnEBNyr7uaZa4rYEwmnySBesF
K5pI0Lh2PpbIILvSsPGP2KxFRv+qZ2C0d35qHzwaUnoEPQc8hQ2E0B92CvdqFN9y4zR8V05W
AT558aopO2z6+I9tTcg1367r3CTueUWnhbYFiN6IXSV8l2RnCdm/WhUFhvMJHuxYMjMR83dk
sHYf5BA1FxvyDrFspCqjc/wJHx4yGVMR59mzLC52LqGj3n5qiAno8geK+LLNEOfic0CTuwjR
P+H8C5SzJe98ptfRr5//lpr1kXuYC3fUfugH0mK1lTnj8/FtDw5lhIpjVMWAtuCeS31HJqcB
CF3RiJ7XwzJE+oJKCmhUfzhTA8ykADNkUVkLo4KRel7sFsLzKuZi2irbWWIQJUoqgQtHB0MG
cIfS+pMRKXpITeuUx3BNr2fVUbGAIAEBtHoIppB/TuDvB0GHr2qlXov7z1CymlSvw4m6WC31
MJixNnI5fkkE/SmnTHnkBVfblLkWU41Gsx2VYVdWf6/wFlthWG82UBEL2KwrlRYaDh8IzTY0
ZRBiZtWAXxQgXy0MoHgKaNYs1+lvK9JKBZP8nm9rZ/+I8U6laUpSNwXqxhaN0sSZ0YIrO7o1
dfdRUVjzyAfd5LQDfwIDAQABo0IwQDAdBgNVHQ4EFgQU2XQ65DA9DfcS3H5aBZ8eNJr34RQw
DwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAYYwDQYJKoZIhvcNAQELBQADggIBADaN
l8xCFWQpN5smLNb7rhVpLGsaGvdftvkHTFnq88nIua7Mui563MD1sC3AO6+fcAURap8lTwEp
cOPlDOHqWnzcSbvBHiqB9RZLcpHIojG5qtr8nR/zXUACE/xOHAbKsxSQVBcZEhrxH9cMaVr2
cXj0lH2RC47skFSOvG+hTKv8dGT9cZr4QQehzZHkPJrgmzI5c6sq1WnIeJEmMX3ixzDx/BR4
dxIOE/TdFpS/S2d7cFOFyrC78zhNLJA5wA3CXWvp4uXViI3WLL+rG761KIcSF3Ru/H38j9CH
JrAb+7lsq+KePRXBOy5nAliRn+/4Qh8st2j1da3Ptfb/EX3C8CSlrdP6oDyp+l3cpaDvRKS+
1ujl5BOWF3sGPjLtx7dCvHaj2GU4Kzg1USEODm8uNBNA4StnDG1KQTAYI1oyVZnJF+A83vbs
ea0rWBmirSwiGpWOvpaQXUJXxPkUAzUrHC1RVwinOt4/5Mi0A3PCwSaAuwtCH60NryZy2sy+
s6ODWA2CxR9GUeOcGMyNm43sSet1UNWMKFnKdDTajAshqx7qG+XH/RU+wBeq+yNuJkbL+vmx
cmtpzyKEC2IPrNkZAJSidjzULZrtBJ4tBmIQN1IchXIbJ+XMxjHsN+xjWZsLHXbMfjKaiJUI
NlK73nZfdklJrX+9ZSCyycErdhh2n1ax
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIGWzCCBEOgAwIBAgIRAMrpG4nxVQMNo+ZBbcTjpuEwDQYJKoZIhvcNAQELBQAwWjELMAkG
A1UEBhMCRlIxEjAQBgNVBAoMCURoaW15b3RpczEcMBoGA1UECwwTMDAwMiA0ODE0NjMwODEw
MDAzNjEZMBcGA1UEAwwQQ2VydGlnbmEgUm9vdCBDQTAeFw0xMzEwMDEwODMyMjdaFw0zMzEw
MDEwODMyMjdaMFoxCzAJBgNVBAYTAkZSMRIwEAYDVQQKDAlEaGlteW90aXMxHDAaBgNVBAsM
EzAwMDIgNDgxNDYzMDgxMDAwMzYxGTAXBgNVBAMMEENlcnRpZ25hIFJvb3QgQ0EwggIiMA0G
CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDNGDllGlmx6mQWDoyUJJV8g9PFOSbcDO8WV43X
2KyjQn+Cyu3NW9sOty3tRQgXstmzy9YXUnIo245Onoq2C/mehJpNdt4iKVzSs9IGPjA5qXSj
klYcoW9MCiBtnyN6tMbaLOQdLNyzKNAT8kxOAkmhVECe5uUFoC2EyP+YbNDrihqECB63aCPu
I9Vwzm1RaRDuoXrC0SIxwoKF0vJVdlB8JXrJhFwLrN1CTivngqIkicuQstDuI7pmTLtipPlT
WmR7fJj6o0ieD5Wupxj0auwuA0Wv8HT4Ks16XdG+RCYyKfHx9WzMfgIhC59vpD++nVPiz32p
LHxYGpfhPTc3GGYo0kDFUYqMwy3OU4gkWGQwFsWq4NYKpkDfePb1BHxpE4S80dGnBs8B92jA
qFe7OmGtBIyT46388NtEbVncSVmurJqZNjBBe3YzIoejwpKGbvlw7q6Hh5UbxHq9MfPU0uWZ
/75I7HX1eBYdpnDBfzwboZL7z8g81sWTCo/1VTp2lc5ZmIoJlXcymoO6LAQ6l73UL77XbJui
yn1tJslV1c/DeVIICZkHJC1kJWumIWmbat10TWuXekG9qxf5kBdIjzb5LdXF2+6qhUVB+s06
RbFo5jZMm5BX7CO5hwjCxAnxl4YqKE3idMDaxIzb3+KhF1nOJFl0Mdp//TBt2dzhauH8XwID
AQABo4IBGjCCARYwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE
FBiHVuBud+4kNTxOc5of1uHieX4rMB8GA1UdIwQYMBaAFBiHVuBud+4kNTxOc5of1uHieX4r
MEQGA1UdIAQ9MDswOQYEVR0gADAxMC8GCCsGAQUFBwIBFiNodHRwczovL3d3d3cuY2VydGln
bmEuZnIvYXV0b3JpdGVzLzBtBgNVHR8EZjBkMC+gLaArhilodHRwOi8vY3JsLmNlcnRpZ25h
LmZyL2NlcnRpZ25hcm9vdGNhLmNybDAxoC+gLYYraHR0cDovL2NybC5kaGlteW90aXMuY29t
L2NlcnRpZ25hcm9vdGNhLmNybDANBgkqhkiG9w0BAQsFAAOCAgEAlLieT/DjlQgi581oQfcc
VdV8AOItOoldaDgvUSILSo3L6btdPrtcPbEo/uRTVRPPoZAbAh1fZkYJMyjhDSSXcNMQH+pk
V5a7XdrnxIxPTGRGHVyH41neQtGbqH6mid2PHMkwgu07nM3A6RngatgCdTer9zQoKJHyBApP
NeNgJgH60BGM+RFq7q89w1DTj18zeTyGqHNFkIwgtnJzFyO+B2XleJINugHA64wcZr+shncB
lA2c5uk5jR+mUYyZDDl34bSb+hxnV29qao6pK0xXeXpXIs/NX2NGjVxZOob4Mkdio2cNGJHc
+6Zr9UhhcyNZjgKnvETq9Emd8VRY+WCv2hikLyhF3HqgiIZd8zvn/yk1gPxkQ5Tm4xxvvq0O
KmOZK8l+hfZx6AYDlf7ej0gcWtSS6Cvu5zHbugRqh5jnxV/vfaci9wHYTfmJ0A6aBVmknpjZ
byvKcL5kwlWj9Omvw5Ip3IgWJJk8jSaYtlu3zM63Nwf9JtmYhST/WSMDmu2dnajkXjjO11IN
b9I/bbEFa0nOipFGc/T2L/Coc3cOZayhjWZSaX5LaAzHHjcng6WMxwLkFM1JAbBzs/3GkDpv
0mztO+7skb6iQ12LAEpmJURw3kAP+HwV96LOPNdeE4yBFxgX0b3xdxA61GU5wSesVywlVP+i
2k+KYTlerj1KjL0=
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIDlDCCAnygAwIBAgIKMfXkYgxsWO3W2DANBgkqhkiG9w0BAQsFADBnMQswCQYDVQQGEwJJ
TjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNobm9sb2dpZXMg
TGltaXRlZDEcMBoGA1UEAxMTZW1TaWduIFJvb3QgQ0EgLSBHMTAeFw0xODAyMTgxODMwMDBa
Fw00MzAyMTgxODMwMDBaMGcxCzAJBgNVBAYTAklOMRMwEQYDVQQLEwplbVNpZ24gUEtJMSUw
IwYDVQQKExxlTXVkaHJhIFRlY2hub2xvZ2llcyBMaW1pdGVkMRwwGgYDVQQDExNlbVNpZ24g
Um9vdCBDQSAtIEcxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAk0u76WaK7p1b
1TST0Bsew+eeuGQzf2N4aLTNLnF115sgxk0pvLZoYIr3IZpWNVrzdr3YzZr/k1ZLpVkGoZM0
Kd0WNHVO8oG0x5ZOrRkVUkr+PHB1cM2vK6sVmjM8qrOLqs1D/fXqcP/tzxE7lM5OMhbTI0Aq
d7OvPAEsbO2ZLIvZTmmYsvePQbAyeGHWDV/D+qJAkh1cF+ZwPjXnorfCYuKrpDhMtTk1b+oD
afo6VGiFbdbyL0NVHpENDtjVaqSW0RM8LHhQ6DqS0hdW5TUaQBw+jSztOd9C4INBdN+jzcKG
YEho42kLVACL5HZpIQ15TjQIXhTCzLG3rdd8cIrHhQIDAQABo0IwQDAdBgNVHQ4EFgQU++8N
hp6w492pufEhF38+/PB3KxowDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wDQYJ
KoZIhvcNAQELBQADggEBAFn/8oz1h31xPaOfG1vR2vjTnGs2vZupYeveFix0PZ7mddrXuqe8
QhfnPZHr5X3dPpzxz5KsbEjMwiI/aTvFthUvozXGaCocV685743QNcMYDHsAVhzNixl03r4P
EuDQqqE/AjSxcM6dGNYIAwlG7mDgfrbESQRRfXBgvKqy/3lyeqYdPV8q+Mri/Tm3R7nrft8E
I6/6nAYH6ftjk4BAtcZsCjEozgyfz7MjNYBBjWzEN3uBL4ChQEKF6dk4jeihU80Bv2noWgby
RQuQ+q7hv53yrlc8pa6yVvSLZUDp/TGBLPQ5Cdjua6e0ph0VpZj3AYHYhX3zUVxxiN66zB+A
fko=
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIICTjCCAdOgAwIBAgIKPPYHqWhwDtqLhDAKBggqhkjOPQQDAzBrMQswCQYDVQQGEwJJTjET
MBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNobm9sb2dpZXMgTGlt
aXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0gRzMwHhcNMTgwMjE4MTgzMDAw
WhcNNDMwMjE4MTgzMDAwWjBrMQswCQYDVQQGEwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTEl
MCMGA1UEChMcZU11ZGhyYSBUZWNobm9sb2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWdu
IEVDQyBSb290IENBIC0gRzMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3i
AhKAnjlfSU2fySU0WXTsuwYc58Byr+iuL+FBVIcUqEqy6HyC5ltqtdyzdc6LBtCGI79G1Y4P
PwT01xySfvalY8L1X44uT6EYGQIrMgqCZH0Wk9GjQjBAMB0GA1UdDgQWBBR8XQKEE9TMipuB
zhccLikenEhjQjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQD
AwNpADBmAjEAvvNhzwIQHWSVB7gYboiFBS+DCBeQyh+KTOgNG3qxrdWBCUfvO6wIBHxcmbHt
RwfSAjEAnbpV/KlK6O3t5nYBQnvI+GDZjVGLVTv7jHvrZQnD+JbNR6iC8hZVdyR+EhCVBCyj
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIDczCCAlugAwIBAgILAK7PALrEzzL4Q7IwDQYJKoZIhvcNAQELBQAwVjELMAkGA1UEBhMC
VVMxEzARBgNVBAsTCmVtU2lnbiBQS0kxFDASBgNVBAoTC2VNdWRocmEgSW5jMRwwGgYDVQQD
ExNlbVNpZ24gUm9vdCBDQSAtIEMxMB4XDTE4MDIxODE4MzAwMFoXDTQzMDIxODE4MzAwMFow
VjELMAkGA1UEBhMCVVMxEzARBgNVBAsTCmVtU2lnbiBQS0kxFDASBgNVBAoTC2VNdWRocmEg
SW5jMRwwGgYDVQQDExNlbVNpZ24gUm9vdCBDQSAtIEMxMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAz+upufGZBczYKCFK83M0UYRWEPWgTywS4/oTmifQz/l5GnRfHXk5/Fv4
cI7gklL35CX5VIPZHdPIWoU/Xse2B+4+wM6ar6xWQio5JXDWv7V7Nq2s9nPczdcdioOl+yuQ
FTdrHCZH3DspVpNqs8FqOp099cGXOFgFixwR4+S0uF2FHYP+eF8LRWgYSKVGczQ7/g/IdrvH
GPMF0Ybzhe3nudkyrVWIzqa2kbBPrH4VI5b2P/AgNBbeCsbEBEV5f6f9vtKppa+cxSMq9zwh
bL2vj07FOrLzNBL834AaSaTUqZX3noleoomslMuoaJuvimUnzYnu3Yy1aylwQ6BpC+S5DwID
AQABo0IwQDAdBgNVHQ4EFgQU/qHgcB4qAzlSWkK+XJGFehiqTbUwDgYDVR0PAQH/BAQDAgEG
MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAMJKVvoVIXsoounlHfv4LcQ5
lkFMOycsxGwYFYDGrK9HWS8mC+M2sO87/kOXSTKZEhVb3xEp/6tT+LvBeA+snFOvV71ojD1p
M/CjoCNjO2RnIkSt1XHLVip4kqNPEjE2NuLe/gDEo2APJ62gsIq1NnpSob0n9CAnYuhNlCQT
5AoE6TyrLshDCUrGYQTlSTR+08TI9Q/Aqum6VF7zYytPT1DU/rl7mYw9wC68AivTxEDkigcx
HpvOJpkT+xHqmiIMERnHXhuBUDDIlhJu58tBf5E7oke3VIAb3ADMmpDqw8NQBmIMMMAVSKeo
WXzhriKi4gp6D/piq1JM4fHfyr6DDUI=
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIICKzCCAbGgAwIBAgIKe3G2gla4EnycqDAKBggqhkjOPQQDAzBaMQswCQYDVQQGEwJVUzET
MBEGA1UECxMKZW1TaWduIFBLSTEUMBIGA1UEChMLZU11ZGhyYSBJbmMxIDAeBgNVBAMTF2Vt
U2lnbiBFQ0MgUm9vdCBDQSAtIEMzMB4XDTE4MDIxODE4MzAwMFoXDTQzMDIxODE4MzAwMFow
WjELMAkGA1UEBhMCVVMxEzARBgNVBAsTCmVtU2lnbiBQS0kxFDASBgNVBAoTC2VNdWRocmEg
SW5jMSAwHgYDVQQDExdlbVNpZ24gRUNDIFJvb3QgQ0EgLSBDMzB2MBAGByqGSM49AgEGBSuB
BAAiA2IABP2lYa57JhAd6bciMK4G9IGzsUJxlTm801Ljr6/58pc1kjZGDoeVjbk5Wum739D+
yAdBPLtVb4OjavtisIGJAnB9SMVK4+kiVCJNk7tCDK93nCOmfddhEc5lx/h//vXyqaNCMEAw
HQYDVR0OBBYEFPtaSNCAIEDyqOkAB2kZd6fmw/TPMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMB
Af8EBTADAQH/MAoGCCqGSM49BAMDA2gAMGUCMQC02C8Cif22TGK6Q04ThHK1rt0c3ta13FaP
WEBaLd4gTCKDypOofu4SQMfWh0/434UCMBwUZOR8loMRnLDRWmFLpg9J0wD8ofzkpf9/rdcw
0Md3f76BB1UwUCAU9Vc4CqgxUQ==
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIFzzCCA7egAwIBAgIUCBZfikyl7ADJk0DfxMauI7gcWqQwDQYJKoZIhvcNAQELBQAwbzEL
MAkGA1UEBhMCSEsxEjAQBgNVBAgTCUhvbmcgS29uZzESMBAGA1UEBxMJSG9uZyBLb25nMRYw
FAYDVQQKEw1Ib25na29uZyBQb3N0MSAwHgYDVQQDExdIb25na29uZyBQb3N0IFJvb3QgQ0Eg
MzAeFw0xNzA2MDMwMjI5NDZaFw00MjA2MDMwMjI5NDZaMG8xCzAJBgNVBAYTAkhLMRIwEAYD
VQQIEwlIb25nIEtvbmcxEjAQBgNVBAcTCUhvbmcgS29uZzEWMBQGA1UEChMNSG9uZ2tvbmcg
UG9zdDEgMB4GA1UEAxMXSG9uZ2tvbmcgUG9zdCBSb290IENBIDMwggIiMA0GCSqGSIb3DQEB
AQUAA4ICDwAwggIKAoICAQCziNfqzg8gTr7m1gNt7ln8wlffKWihgw4+aMdoWJwcYEuJQwy5
1BWy7sFOdem1p+/l6TWZ5Mwc50tfjTMwIDNT2aa71T4Tjukfh0mtUC1Qyhi+AViiE3CWu4mI
VoBc+L0sPOFMV4i707mV78vH9toxdCim5lSJ9UExyuUmGs2C4HDaOym71QP1mbpV9WTRYA6z
iUm4ii8F0oRFKHyPaFASePwLtVPLwpgchKOesL4jpNrcyCse2m5FHomY2vkALgbpDDtw1VAl
iJnLzXNg99X/NWfFobxeq81KuEXryGgeDQ0URhLj0mRiikKYvLTGCAj4/ahMZJx2Ab0vqWwz
D9g/KLg8aQFChn5pwckGyuV6RmXpwtZQQS4/t+TtbNe/JgERohYpSms0BpDsE9K2+2p20jzt
8NYt3eEV7KObLyzJPivkaTv/ciWxNoZbx39ri1UbSsUgYT2uy1DhCDq+sI9jQVMwCFk8mB13
umOResoQUGC/8Ne8lYePl8X+l2oBlKN8W4UdKjk60FSh0Tlxnf0h+bV78OLgAo9uliQlLKAe
LKjEiafv7ZkGL7YKTE/bosw3Gq9HhS2KX8Q0NEwA/RiTZxPRN+ZItIsGxVd7GYYKecsAyVKv
Qv83j+GjHno9UKtjBucVtT+2RTeUN7F+8kjDf8V1/peNRY8apxpyKBpADwIDAQABo2MwYTAP
BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAfBgNVHSMEGDAWgBQXnc0ei9Y5K3DT
XNSguB+wAPzFYTAdBgNVHQ4EFgQUF53NHovWOStw01zUoLgfsAD8xWEwDQYJKoZIhvcNAQEL
BQADggIBAFbVe27mIgHSQpsY1Q7XZiNc4/6gx5LS6ZStS6LG7BJ8dNVI0lkUmcDrudHr9Egw
W62nV3OZqdPlt9EuWSRY3GguLmLYauRwCy0gUCCkMpXRAJi70/33MvJJrsZ64Ee+bs7Lo3I6
LWldy8joRTnU+kLBEUx3XZL7av9YROXrgZ6voJmtvqkBZss4HTzfQx/0TW60uhdG/H39h4F5
ag0zD/ov+BS5gLNdTaqX4fnkGMX41TiMJjz98iji7lpJiCzfeT2OnpA8vUFKOt1b9pq0zj8l
MH8yfaIDlNDceqFS3m6TjRgm/VWsvY+b0s+v54Ysyx8Jb6NvqYTUc79NoXQbTiNg8swOqn+k
nEwlqLJmOzj/2ZQw9nKEvmhVEA/GcywWaZMH/rFF7buiVWqw2rVKAiUnhde3t4ZEFolsgCs+
l6mc1X5VTMbeRRAc6uk7nwNT7u56AQIWeNTowr5GdogTPyK7SBIdUgC0An4hGh6cJfTzPV4e
0hz5sy229zdcxsshTrD3mUcYhcErulWuBurQB7Lcq9CClnXO0lD+mefPL5/ndtFhKvshuzHQ
qp9HpLIiyhY6UFfEW0NnxWViA0kB60PZ2Pierc+xYw5F9KBaLJstxabArahH9CdMOA0uG0k7
UvToiIMrVCjU8jVStDKDYmlkDJGcn5fqdBb9HxEGmpv0
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIGSzCCBDOgAwIBAgIRANm1Q3+vqTkPAAAAAFVlrVgwDQYJKoZIhvcNAQELBQAwgb4xCzAJ
BgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSgwJgYDVQQLEx9TZWUgd3d3LmVu
dHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQLEzAoYykgMjAxNSBFbnRydXN0LCBJbmMu
IC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxMjAwBgNVBAMTKUVudHJ1c3QgUm9vdCBDZXJ0
aWZpY2F0aW9uIEF1dGhvcml0eSAtIEc0MB4XDTE1MDUyNzExMTExNloXDTM3MTIyNzExNDEx
Nlowgb4xCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSgwJgYDVQQLEx9T
ZWUgd3d3LmVudHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQLEzAoYykgMjAxNSBFbnRy
dXN0LCBJbmMuIC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxMjAwBgNVBAMTKUVudHJ1c3Qg
Um9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEc0MIICIjANBgkqhkiG9w0BAQEFAAOC
Ag8AMIICCgKCAgEAsewsQu7i0TD/pZJH4i3DumSXbcr3DbVZwbPLqGgZ2K+EbTBwXX7zLtJT
meH+H17ZSK9dE43b/2MzTdMAArzE+NEGCJR5WIoV3imz/f3ET+iq4qA7ec2/a0My3dl0ELn3
9GjUu9CH1apLiipvKgS1sqbHoHrmSKvS0VnM1n4j5pds8ELl3FFLFUHtSUrJ3hCX1nbB76W1
NhSXNdh4IjVS70O92yfbYVaCNNzLiGAMC1rlLAHGVK/XqsEQe9IFWrhAnoanw5CGAlZSCXqc
0ieCU0plUmr1POeo8pyvi73TDtTUXm6Hnmo9RR3RXRv06QqsYJn7ibT/mCzPfB3pAqoEmh64
3IhuJbNsZvc8kPNXwbMv9W3y+8qh+CmdRouzavbmZwe+LGcKKh9asj5XxNMhIWNlUpEbsZmO
eX7m640A2Vqq6nPopIICR5b+W45UYaPrL0swsIsjdXJ8ITzI9vF01Bx7owVV7rtNOzK+mndm
nqxpkCIHH2E6lr7lmk/MBTwoWdPBDFSoWWG9yHJM6Nyfh3+9nEg2XpWjDrk4JFX8dWbrAuMI
NClKxuMrLzOg2qOGpRKX/YAr2hRC45K9PvJdXmd0LhyIRyk0X+IyqJwlN4y6mACXi0mWHv0l
iqzc2thddG5msP9E36EYxr5ILzeUePiVSj9/E15dWf10hkNjc0kCAwEAAaNCMEAwDwYDVR0T
AQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFJ84xFYjwznooHFs6FRM5Og6
sb9nMA0GCSqGSIb3DQEBCwUAA4ICAQAS5UKme4sPDORGpbZgQIeMJX6tuGguW8ZAdjwD+MlZ
9POrYs4QjbRaZIxowLByQzTSGwv2LFPSypBLhmb8qoMi9IsabyZIrHZ3CL/FmFz0Jomee8O5
ZDIBf9PD3Vht7LGrhFV0d4QEJ1JrhkzO3bll/9bGXp+aEJlLdWr+aumXIOTkdnrG0CSqkM0g
kLpHZPt/B7NTeLUKYvJzQ85BK4FqLoUWlFPUa19yIqtRLULVAJyZv967lDtX/Zr1hstWO1uI
AeV8KEsD+UmDfLJ/fOPtjqF/YFOOVZ1QNBIPt5d7bIdKROf1beyAN/BYGW5KaHbwH5Lk6rWS
02FREAutp9lfx1/cH6NcjKF+m7ee01ZvZl4HliDtC3T7Zk6LERXpgUl+b7DUUH8i119lAg2m
9IUe2K4GS0qn0jFmwvjO5QimpAKWRGhXxNUzzxkvFMSUHHuk2fCfDrGA4tGeEWSpiBE6doLl
YsKA2KSD7ZPvfC+QsDJMlhVoSFLUmQjAJOgc47OlIQ6SwJAfzyBfyjs4x7dtOvPmRLgOMWuI
jnDrnBdSqEGULoe256YSxXXfW8AKbnuk5F6G+TaU33fD6Q3AOfF5u0aOq0NZJ7cguyPpVkAh
7DE9ZapD8j3fcEThuk0mEDuYn/PIjhs4ViFqUZPTkcpG2om3PVODLAgfi49T3f+sHw==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICWTCCAd+gAwIBAgIQZvI9r4fei7FK6gxXMQHC7DAKBggqhkjOPQQDAzBlMQswCQYDVQQG
EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTYwNAYDVQQDEy1NaWNyb3Nv
ZnQgRUNDIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTcwHhcNMTkxMjE4MjMwNjQ1
WhcNNDIwNzE4MjMxNjA0WjBlMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENv
cnBvcmF0aW9uMTYwNAYDVQQDEy1NaWNyb3NvZnQgRUNDIFJvb3QgQ2VydGlmaWNhdGUgQXV0
aG9yaXR5IDIwMTcwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAATUvD0CQnVBEyPNgASGAlEvaqiB
YgtlzPbKnR5vSmZRogPZnZH6thaxjG7efM3beaYvzrvOcS/lpaso7GMEZpn4+vKTEAXhgShC
48Zo9OYbhGBKia/teQ87zvH2RPUBeMCjVDBSMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8E
BTADAQH/MB0GA1UdDgQWBBTIy5lycFIM+Oa+sgRXKSrPQhDtNTAQBgkrBgEEAYI3FQEEAwIB
ADAKBggqhkjOPQQDAwNoADBlAjBY8k3qDPlfXu5gKcs68tvWMoQZP3zVL8KxzJOuULsJMsbG
7X7JNpQS5GiFBqIb0C8CMQCZ6Ra0DvpWSNSkMBaReNtUjGUBiudQZsIxtzm6uBoiB078a1QW
IP8rtedMDE2mT3M=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFqDCCA5CgAwIBAgIQHtOXCV/YtLNHcB6qvn9FszANBgkqhkiG9w0BAQwFADBlMQswCQYD
VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTYwNAYDVQQDEy1NaWNy
b3NvZnQgUlNBIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTcwHhcNMTkxMjE4MjI1
MTIyWhcNNDIwNzE4MjMwMDIzWjBlMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0
IENvcnBvcmF0aW9uMTYwNAYDVQQDEy1NaWNyb3NvZnQgUlNBIFJvb3QgQ2VydGlmaWNhdGUg
QXV0aG9yaXR5IDIwMTcwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDKW76UM4wp
lZEWCpW9R2LBifOZNt9GkMml7Xhqb0eRaPgnZ1AzHaGm++DlQ6OEAlcBXZxIQIJTELy/xzto
kLaCLeX0ZdDMbRnMlfl7rEqUrQ7eS0MdhweSE5CAg2Q1OQT85elss7YfUJQ4ZVBcF0a5toW1
HLUX6NZFndiyJrDKxHBKrmCk3bPZ7Pw71VdyvD/IybLeS2v4I2wDwAW9lcfNcztmgGTjGqwu
+UcF8ga2m3P1eDNbx6H7JyqhtJqRjJHTOoI+dkC0zVJhUXAoP8XFWvLJjEm7FFtNyP9nTUwS
lq31/niol4fX/V4ggNyhSyL71Imtus5Hl0dVe49FyGcohJUcaDDv70ngNXtk55iwlNpNhTs+
VcQor1fznhPbRiefHqJeRIOkpcrVE7NLP8TjwuaGYaRSMLl6IE9vDzhTyzMMEyuP1pq9Ksgt
sRx9S1HKR9FIJ3Jdh+vVReZIZZ2vUpC6W6IYZVcSn2i51BVrlMRpIpj0M+Dt+VGOQVDJNE92
kKz8OMHY4Xu54+OU4UZpyw4KUGsTuqwPN1q3ErWQgR5WrlcihtnJ0tHXUeOrO8ZV/R4O03QK
0dqq6mm4lyiPSMQH+FJDOvTKVTUssKZqwJz58oHhEmrARdlns87/I6KJClTUFLkqqNfs+avN
JVgyeY+QW5g5xAgGwax/Dj0ApQIDAQABo1QwUjAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQUCctZf4aycI8awznjwNnpv7tNsiMwEAYJKwYBBAGCNxUBBAMC
AQAwDQYJKoZIhvcNAQEMBQADggIBAKyvPl3CEZaJjqPnktaXFbgToqZCLgLNFgVZJ8og6Lq4
6BrsTaiXVq5lQ7GPAJtSzVXNUzltYkyLDVt8LkS/gxCP81OCgMNPOsduET/m4xaRhPtthH80
dK2Jp86519efhGSSvpWhrQlTM93uCupKUY5vVau6tZRGrox/2KJQJWVggEbbMwSubLWYdFQl
3JPk+ONVFT24bcMKpBLBaYVu32TxU5nhSnUgnZUP5NbcA/FZGOhHibJXWpS2qdgXKxdJ5XbL
wVaZOjex/2kskZGT4d9Mozd2TaGf+G0eHdP67Pv0RR0Tbc/3WeUiJ3IrhvNXuzDtJE3cfVa7
o7P4NHmJweDyAmH3pvwPuxwXC65B2Xy9J6P9LjrRk5Sxcx0ki69bIImtt2dmefU6xqaWM/5T
kshGsRGRxpl/j8nWZjEgQRCHLQzWwa80mMpkg/sTV9HB8Dx6jKXB/ZUhoHHBk2dxEuqPiApp
GWSZI1b7rCoucL5mxAyE7+WL85MB+GqQk2dLsmijtWKP6T+MejteD+eMuMZ87zf9dOLITzNy
4ZQ5bb0Sr74MTnB8G2+NszKTc0QWbej09+CVgI+WXTik9KveCjCHk9hNAHFiRSdLOkKEW39l
t2c0Ui2cFmuqqNh7o0JMcccMyj6D5KbvtwEwXlGjefVwaaZBRA+GsCyRxj3qrg+E
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICQDCCAeWgAwIBAgIMAVRI7yH9l1kN9QQKMAoGCCqGSM49BAMCMHExCzAJBgNVBAYTAkhV
MREwDwYDVQQHDAhCdWRhcGVzdDEWMBQGA1UECgwNTWljcm9zZWMgTHRkLjEXMBUGA1UEYQwO
VkFUSFUtMjM1ODQ0OTcxHjAcBgNVBAMMFWUtU3ppZ25vIFJvb3QgQ0EgMjAxNzAeFw0xNzA4
MjIxMjA3MDZaFw00MjA4MjIxMjA3MDZaMHExCzAJBgNVBAYTAkhVMREwDwYDVQQHDAhCdWRh
cGVzdDEWMBQGA1UECgwNTWljcm9zZWMgTHRkLjEXMBUGA1UEYQwOVkFUSFUtMjM1ODQ0OTcx
HjAcBgNVBAMMFWUtU3ppZ25vIFJvb3QgQ0EgMjAxNzBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABJbcPYrYsHtvxie+RJCxs1YVe45DJH0ahFnuY2iyxl6H0BVIHqiQrb1TotreOpCmYF9o
MrWGQd+HWyx7xf58etqjYzBhMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0G
A1UdDgQWBBSHERUI0arBeAyxr87GyZDvvzAEwDAfBgNVHSMEGDAWgBSHERUI0arBeAyxr87G
yZDvvzAEwDAKBggqhkjOPQQDAgNJADBGAiEAtVfd14pVCzbhhkT61NlojbjcI4qKDdQvfepz
7L9NbKgCIQDLpbQS+ue16M9+k/zzNY9vTlp8tLxOsvxyqltZ+efcMQ==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFRzCCAy+gAwIBAgIJEQA0tk7GNi02MA0GCSqGSIb3DQEBCwUAMEExCzAJBgNVBAYTAlJP
MRQwEgYDVQQKEwtDRVJUU0lHTiBTQTEcMBoGA1UECxMTY2VydFNJR04gUk9PVCBDQSBHMjAe
Fw0xNzAyMDYwOTI3MzVaFw00MjAyMDYwOTI3MzVaMEExCzAJBgNVBAYTAlJPMRQwEgYDVQQK
EwtDRVJUU0lHTiBTQTEcMBoGA1UECxMTY2VydFNJR04gUk9PVCBDQSBHMjCCAiIwDQYJKoZI
hvcNAQEBBQADggIPADCCAgoCggIBAMDFdRmRfUR0dIf+DjuW3NgBFszuY5HnC2/OOwppGnzC
46+CjobXXo9X69MhWf05N0IwvlDqtg+piNguLWkh59E3GE59kdUWX2tbAMI5Qw02hVK5U2UP
HULlj88F0+7cDBrZuIt4ImfkabBoxTzkbFpG583H+u/E7Eu9aqSs/cwoUe+StCmrqzWaTOTE
CMYmzPhpn+Sc8CnTXPnGFiWeI8MgwT0PPzhAsP6CRDiqWhqKa2NYOLQV07YRaXseVO6MGiKs
cpc/I1mbySKEwQdPzH/iV8oScLumZfNpdWO9lfsbl83kqK/20U6o2YpxJM02PbyWxPFsqa7l
zw1uKA2wDrXKUXt4FMMgL3/7FFXhEZn91QqhngLjYl/rNUssuHLoPj1PrCy7Lobio3aP5ZMq
z6WryFyNSwb/EkaseMsUBzXgqd+L6a8VTxaJW732jcZZroiFDsGJ6x9nxUWO/203Nit4ZoOR
USs9/1F3dmKh7Gc+PoGD4FapUB8fepmrY7+EF3fxDTvf95xhszWYijqy7DwaNz9+j5LP2RIU
ZNoQAhVB/0/E6xyjyfqZ90bp4RjZsbgyLcsUDFDYg2WD7rlcz8sFWkz6GZdr1l0T08JcVLwy
c6B49fFtHsufpaafItzRUZ6CeWRgKRM+o/1Pcmqr4tTluCRVLERLiohEnMqE0yo7AgMBAAGj
QjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBSCIS1mxteg
4BXrzkwJd8RgnlRuAzANBgkqhkiG9w0BAQsFAAOCAgEAYN4auOfyYILVAzOBywaK8SJJ6ejq
kX/GM15oGQOGO0MBzwdw5AgeZYWR5hEit/UCI46uuR59H35s5r0l1ZUa8gWmr4UCb6741jH/
JclKyMeKqdmfS0mbEVeZkkMR3rYzpMzXjWR91M08KCy0mpbqTfXERMQlqiCA2ClV9+BB/AYm
/7k29UMUA2Z44RGx2iBfRgB4ACGlHgAoYXhvqAEBj500mv/0OJD7uNGzcgbJceaBxXntC6Z5
8hMLnPddDnskk7RI24Zf3lCGeOdA5jGokHZwYa+cNywRtYK3qq4kNFtyDGkNzVmf9nGvnAvR
Cjj5BiKDUyUM/FHE5r7iOZULJK2v0ZXkltd0ZGtxTgI8qoXzIKNDOXZbbFD+mpwUHmUUihW9
o4JFWklWatKcsWMy5WHgUyIOpwpJ6st+H6jiYoD2EEVSmAYY3qXNL3+q1Ok+CHLsIwMCPKaq
2LxndD0UF/tUSxfj03k9bWtJySgOLnRQvwzZRjoQhsmnP+mg7H/rpXdYaXHmgwo38oZJar55
CJD2AhZkPuXaTH4MNMn5X7azKFGnpyuqSfqNZSlO42sTp5SjLVFteAxEy9/eCG/Oo2Sr05WE
1LlSVHJ7liXMvGnjSG4N0MedJ5qq+BOS3R7fY581qRY27Iy4g/Q9iY/NtBde17MXQRBdJ3Ng
hVdJIgc=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIF2jCCA8KgAwIBAgIMBfcOhtpJ80Y1LrqyMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQG
EwJVUzERMA8GA1UECAwISWxsaW5vaXMxEDAOBgNVBAcMB0NoaWNhZ28xITAfBgNVBAoMGFRy
dXN0d2F2ZSBIb2xkaW5ncywgSW5jLjExMC8GA1UEAwwoVHJ1c3R3YXZlIEdsb2JhbCBDZXJ0
aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xNzA4MjMxOTM0MTJaFw00MjA4MjMxOTM0MTJaMIGI
MQswCQYDVQQGEwJVUzERMA8GA1UECAwISWxsaW5vaXMxEDAOBgNVBAcMB0NoaWNhZ28xITAf
BgNVBAoMGFRydXN0d2F2ZSBIb2xkaW5ncywgSW5jLjExMC8GA1UEAwwoVHJ1c3R3YXZlIEds
b2JhbCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
AgoCggIBALldUShLPDeS0YLOvR29zd24q88KPuFd5dyqCblXAj7mY2Hf8g+CY66j96xz0Xzn
swuvCAAJWX/NKSqIk4cXGIDtiLK0thAfLdZfVaITXdHG6wZWiYj+rDKd/VzDBcdu7oaJuogD
nXIhhpCujwOl3J+IKMujkkkP7NAP4m1ET4BqstTnoApTAbqOl5F2brz81Ws25kCI1nsvXwXo
LG0R8+eyvpJETNKXpP7ScoFDB5zpET71ixpZfR9oWN0EACyW80OzfpgZdNmcc9kYvkHHNHnZ
9GLCQ7mzJ7Aiy/k9UscwR7PJPrhq4ufogXBeQotPJqX+OsIgbrv4Fo7NDKm0G2x2EOFYeUY+
VM6AqFcJNykbmROPDMjWLBz7BegIlT1lRtzuzWniTY+HKE40Cz7PFNm73bZQmq131BnW2hqI
yE4bJ3XYsgjxroMwuREOzYfwhI0Vcnyh78zyiGG69Gm7DIwLdVcEuE4qFC49DxweMqZiNu5m
4iK4BUBjECLzMx10coos9TkpoNPnG4CELcU9402x/RpvumUHO1jsQkUm+9jaJXLE9gCxInm9
43xZYkqcBW89zubWR2OZxiRvchLIrH+QtAuRcOi35hYQcRfO3gZPSEF9NUqjifLJS3tBEW1n
twiYTOURGa5CgNz7kAXU+FDKvuStx8KU1xad5hePrzb7AgMBAAGjQjBAMA8GA1UdEwEB/wQF
MAMBAf8wHQYDVR0OBBYEFJngGWcNYtt2s9o9uFvo/ULSMQ6HMA4GA1UdDwEB/wQEAwIBBjAN
BgkqhkiG9w0BAQsFAAOCAgEAmHNw4rDT7TnsTGDZqRKGFx6W0OhUKDtkLSGm+J1WE2pIPU/H
PinbbViDVD2HfSMF1OQc3Og4ZYbFdada2zUFvXfeuyk3QAUHw5RSn8pk3fEbK9xGChACMf1K
aA0HZJDmHvUqoai7PF35owgLEQzxPy0QlG/+4jSHg9bP5Rs1bdID4bANqKCqRieCNqcVtgim
QlRXtpla4gt5kNdXElE1GYhBaCXUNxeEFfsBctyV3lImIJgm4nb1J2/6ADtKYdkNy1GTKv0W
BpanI5ojSP5RvbbEsLFUzt5sQa0WZ37b/TjNuThOssFgy50X31ieemKyJo90lZvkWx3SD92Y
HJtZuSPTMaCm/zjdzyBP6VhWOmfD0faZmZ26NraAL4hHT4a/RDqA5Dccprrql5gR0IRiR2Qe
qu5AvzSxnI9O4fKSTx+O856X3vOmeWqJcU9LJxdI/uz0UA9PSX3MReO9ekDFQdxhVicGaeVy
QYHTtgGJoC86cnn+OjC/QezHYj6RS8fZMXZC+fc8Y+wmjHMMfRod6qh8h6jCJ3zhM0EPz8/8
AKAigJ5Kp28AsEFFtyLKaEjFQqKu3R3y4G5OBVixwJAWKqQ9EEC+j2Jjg6mcgn0tAumDMHzL
J8n9HmYAsC7TIS+OMxZsmO0QqAfWzJPP29FpHOTKyeC2nOnOcXHebD8WpHk=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIICYDCCAgegAwIBAgIMDWpfCD8oXD5Rld9dMAoGCCqGSM49BAMCMIGRMQswCQYDVQQGEwJV
UzERMA8GA1UECBMISWxsaW5vaXMxEDAOBgNVBAcTB0NoaWNhZ28xITAfBgNVBAoTGFRydXN0
d2F2ZSBIb2xkaW5ncywgSW5jLjE6MDgGA1UEAxMxVHJ1c3R3YXZlIEdsb2JhbCBFQ0MgUDI1
NiBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xNzA4MjMxOTM1MTBaFw00MjA4MjMxOTM1
MTBaMIGRMQswCQYDVQQGEwJVUzERMA8GA1UECBMISWxsaW5vaXMxEDAOBgNVBAcTB0NoaWNh
Z28xITAfBgNVBAoTGFRydXN0d2F2ZSBIb2xkaW5ncywgSW5jLjE6MDgGA1UEAxMxVHJ1c3R3
YXZlIEdsb2JhbCBFQ0MgUDI1NiBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABH77bOYj43MyCMpg5lOcunSNGLB4kFKA3TjASh3RqMyTpJcGOMoN
FWLGjgEqZZ2q3zSRLoHB5DOSMcT9CTqmP62jQzBBMA8GA1UdEwEB/wQFMAMBAf8wDwYDVR0P
AQH/BAUDAwcGADAdBgNVHQ4EFgQUo0EGrJBt0UrrdaVKEJmzsaGLSvcwCgYIKoZIzj0EAwID
RwAwRAIgB+ZU2g6gWrKuEZ+Hxbb/ad4lvvigtwjzRM4q3wghDDcCIC0mA6AFvWvR9lz4ZcyG
bbOcNEhjhAnFjXca4syc4XR7
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIICnTCCAiSgAwIBAgIMCL2Fl2yZJ6SAaEc7MAoGCCqGSM49BAMDMIGRMQswCQYDVQQGEwJV
UzERMA8GA1UECBMISWxsaW5vaXMxEDAOBgNVBAcTB0NoaWNhZ28xITAfBgNVBAoTGFRydXN0
d2F2ZSBIb2xkaW5ncywgSW5jLjE6MDgGA1UEAxMxVHJ1c3R3YXZlIEdsb2JhbCBFQ0MgUDM4
NCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xNzA4MjMxOTM2NDNaFw00MjA4MjMxOTM2
NDNaMIGRMQswCQYDVQQGEwJVUzERMA8GA1UECBMISWxsaW5vaXMxEDAOBgNVBAcTB0NoaWNh
Z28xITAfBgNVBAoTGFRydXN0d2F2ZSBIb2xkaW5ncywgSW5jLjE6MDgGA1UEAxMxVHJ1c3R3
YXZlIEdsb2JhbCBFQ0MgUDM4NCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTB2MBAGByqGSM49
AgEGBSuBBAAiA2IABGvaDXU1CDFHBa5FmVXxERMuSvgQMSOjfoPTfygIOiYaOs+Xgh+AtycJ
j9GOMMQKmw6sWASr9zZ9lCOkmwqKi6vr/TklZvFe/oyujUF5nQlgziip04pt89ZF1PKYhDhl
oKNDMEEwDwYDVR0TAQH/BAUwAwEB/zAPBgNVHQ8BAf8EBQMDBwYAMB0GA1UdDgQWBBRVqYSJ
0sEyvRjLbKYHTsjnnb6CkDAKBggqhkjOPQQDAwNnADBkAjA3AZKXRRJ+oPM+rRk6ct30UJMD
Er5E0k9BpIycnR+j9sKS50gU/k6bpZFXrsY3crsCMGclCrEMXu6pY5Jv5ZAL/mYiykf9ijH3
g/56vxC+GCsej/YpHpRZ744hN8tRmKVuSw==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIFojCCA4qgAwIBAgIUAZQwHqIL3fXFMyqxQ0Rx+NZQTQ0wDQYJKoZIhvcNAQEMBQAwaTEL
MAkGA1UEBhMCS1IxJjAkBgNVBAoMHU5BVkVSIEJVU0lORVNTIFBMQVRGT1JNIENvcnAuMTIw
MAYDVQQDDClOQVZFUiBHbG9iYWwgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0x
NzA4MTgwODU4NDJaFw0zNzA4MTgyMzU5NTlaMGkxCzAJBgNVBAYTAktSMSYwJAYDVQQKDB1O
QVZFUiBCVVNJTkVTUyBQTEFURk9STSBDb3JwLjEyMDAGA1UEAwwpTkFWRVIgR2xvYmFsIFJv
b3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQC21PGTXLVAiQqrDZBbUGOukJR0F0Vy1ntlWilLp1agS7gvQnXp2XskWjFlqxcX0TM6
2RHcQDaH38dq6SZeWYp34+hInDEW+j6RscrJo+KfziFTowI2MMtSAuXaMl3Dxeb57hHHi8lE
HoSTGEq0n+USZGnQJoViAbbJAh2+g1G7XNr4rRVqmfeSVPc0W+m/6imBEtRTkZazkVrd/pBz
KPswRrXKCAfHcXLJZtM0l/aM9BhK4dA9WkW2aacp+yPOiNgSnABIqKYPszuSjXEOdMWLyEz5
9JuOuDxp7W87UC9Y7cSw0BwbagzivESq2M0UXZR4Yb8ObtoqvC8MC3GmsxY/nOb5zJ9TNeID
oKAYv7vxvvTWjIcNQvcGufFt7QSUqP620wbGQGHfnZ3zVHbOUzoBppJB7ASjjw2i1QnK1sua
8e9DXcCrpUHPXFNwcMmIpi3Ua2FzUCaGYQ5fG8Ir4ozVu53BA0K6lNpfqbDKzE0K70dpAy8i
+/Eozr9dUGWokG2zdLAIx6yo0es+nPxdGoMuK8u180SdOqcXYZaicdNwlhVNt0xz7hlcxVs+
Qf6sdWA7G2POAN3aCJBitOUt7kinaxeZVL6HSuOpXgRM6xBtVNbv8ejyYhbLgGvtPe31HzCl
rkvJE+2KAQHJuFFYwGY6sWZLxNUxAmLpdIQM201GLQIDAQABo0IwQDAdBgNVHQ4EFgQU0p+I
36HNLL3s9TsBAZMzJ7LrYEswDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wDQYJ
KoZIhvcNAQEMBQADggIBADLKgLOdPVQG3dLSLvCkASELZ0jKbY7gyKoNqo0hV4/GPnrK21HU
UrPUloSlWGB/5QuOH/XcChWB5Tu2tyIvCZwTFrFsDDUIbatjcu3cvuzHV+YwIHHW1xDBE1UB
jCpD5EHxzzp6U5LOogMFDTjfArsQLtk70pt6wKGm+LUx5vR1yblTmXVHIloUFcd4G7ad6Qz4
G3bxhYTeodoS76TiEJd6eN4MUZeoIUCLhr0N8F5OSza7OyAfikJW4Qsav3vQIkMsRIz75Sq0
bBwcupTgE34h5prCy8VCZLQelHsIJchxzIdFV4XTnyliIoNRlwAYl3dqmJLJfGBs32x9SuRw
TMKeuB330DTHD8z7p/8Dvq1wkNoL3chtl1+afwkyQf3NosxabUzyqkn+Zvjp2DXrDige7kgv
OtB5CTh8piKCk5XQA76+AqAF3SAi428diDRgxuYKuQl1C/AH6GmWNcf7I4GOODm4RStDeKLR
LBT/DShycpWbXgnbiUSYqqFJu3FS8r/2/yehNq+4tneI3TqkbZs0kNwUXTC/t+sX5Ie3cdCh
13cV1ELX8vMxmV2b3RZtP+oGI/hGoiLtk/bdmuYqh7GYVPEi92tF4+KOdh2ajcQGjTa3FPOd
VGm3jjzVpG2Tgbet9r1ke8LJaDmgkpzNNIaRkPpkUZ3+/uul9XXeifdy
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICbjCCAfOgAwIBAgIQYvYybOXE42hcG2LdnC6dlTAKBggqhkjOPQQDAzB4MQswCQYDVQQG
EwJFUzERMA8GA1UECgwIRk5NVC1SQ00xDjAMBgNVBAsMBUNlcmVzMRgwFgYDVQRhDA9WQVRF
Uy1RMjgyNjAwNEoxLDAqBgNVBAMMI0FDIFJBSVogRk5NVC1SQ00gU0VSVklET1JFUyBTRUdV
Uk9TMB4XDTE4MTIyMDA5MzczM1oXDTQzMTIyMDA5MzczM1oweDELMAkGA1UEBhMCRVMxETAP
BgNVBAoMCEZOTVQtUkNNMQ4wDAYDVQQLDAVDZXJlczEYMBYGA1UEYQwPVkFURVMtUTI4MjYw
MDRKMSwwKgYDVQQDDCNBQyBSQUlaIEZOTVQtUkNNIFNFUlZJRE9SRVMgU0VHVVJPUzB2MBAG
ByqGSM49AgEGBSuBBAAiA2IABPa6V1PIyqvfNkpSIeSX0oNnnvBlUdBeh8dHsVnyV0ebAAKT
RBdp20LHsbI6GA60XYyzZl2hNPk2LEnb80b8s0RpRBNm/dfF/a82Tc4DTQdxz69qBdKiQ1oK
Um8BA06Oi6NCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE
FAG5L++/EYZg8k/QQW6rcx/n0m5JMAoGCCqGSM49BAMDA2kAMGYCMQCuSuMrQMN0EfKVrRYj
3k4MGuZdpSRea0R7/DjiT8ucRRcRTBQnJlU5dUoDzBOQn5ICMQD6SmxgiHPz7riYYqnOK8LZ
iqZwMR2vsJRM60/G49HzYqc8/5MuB1xJAWdpEgJyv+c=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIFWjCCA0KgAwIBAgISEdK7udcjGJ5AXwqdLdDfJWfRMA0GCSqGSIb3DQEBDAUAMEYxCzAJ
BgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRwwGgYDVQQDExNHbG9iYWxT
aWduIFJvb3QgUjQ2MB4XDTE5MDMyMDAwMDAwMFoXDTQ2MDMyMDAwMDAwMFowRjELMAkGA1UE
BhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExHDAaBgNVBAMTE0dsb2JhbFNpZ24g
Um9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCsrHQy6LNl5brtQyYd
pokNRbopiLKkHWPd08EsCVeJOaFV6Wc0dwxu5FUdUiXSE2te4R2pt32JMl8Nnp8semNgQB+m
sLZ4j5lUlghYruQGvGIFAha/r6gjA7aUD7xubMLL1aa7DOn2wQL7Id5m3RerdELv8HQvJfTq
a1VbkNud316HCkD7rRlr+/fKYIje2sGP1q7Vf9Q8g+7XFkyDRTNrJ9CG0Bwta/OrffGFqfUo
0q3v84RLHIf8E6M6cqJaESvWJ3En7YEtbWaBkoe0G1h6zD8K+kZPTXhc+CtI4wSEy132tGqz
ZfxCnlEmIyDLPRT5ge1lFgBPGmSXZgjPjHvjK8Cd+RTyG/FWaha/LIWFzXg4mutCagI0GIMX
TpRW+LaCtfOW3T3zvn8gdz57GSNrLNRyc0NXfeD412lPFzYE+cCQYDdF3uYM2HSNrpyibXRd
Qr4G9dlkbgIQrImwTDsHTUB+JMWKmIJ5jqSngiCNI/onccnfxkF0oE32kRbcRoxfKWMxWXEM
2G/CtjJ9++ZdU6Z+Ffy7dXxd7Pj2Fxzsx2sZy/N78CsHpdlseVR2bJ0cpm4O6XkMqCNqo98b
MDGfsVR7/mrLZqrcZdCinkqaByFrgY/bxFn63iLABJzjqls2k+g9vXqhnQt2sQvHnf3PmKgG
wvgqo6GDoLclcqUC4wIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB
/zAdBgNVHQ4EFgQUA1yrc4GHqMywptWU4jaWSf8FmSwwDQYJKoZIhvcNAQEMBQADggIBAHx4
7PYCLLtbfpIrXTncvtgdokIzTfnvpCo7RGkerNlFo048p9gkUbJUHJNOxO97k4VgJuoJSOD1
u8fpaNK7ajFxzHmuEajwmf3lH7wvqMxX63bEIaZHU1VNaL8FpO7XJqti2kM3S+LGteWygxk6
x9PbTZ4IevPuzz5i+6zoYMzRx6Fcg0XERczzF2sUyQQCPtIkpnnpHs6i58FZFZ8d4kuaPp92
CC1r2LpXFNqD6v6MVenQTqnMdzGxRBF6XLE+0xRFFRhiJBPSy03OXIPBNvIQtQ6IbbjhVp+J
3pZmOUdkLG5NrmJ7v2B0GbhWrJKsFjLtrWhV/pi60zTe9Mlhww6G9kuEYO4Ne7UyWHmRVSyB
Q7N0H3qqJZ4d16GLuc1CLgSkZoNNiTW2bKg2SnkheCLQQrzRQDGQob4Ez8pn7fXwgNNgyYMq
IgXQBztSvwyeqiv5u+YfjyW6hY0XHgL+XVAEV8/+LbzvXMAaq7afJMbfc2hIkCwU9D9SGuTS
yxTDYWnP4vkYxboznxSjBF25cfe1lNj2M8FawTSLfJvdkzrnE6JwYZ+vj+vYxXX4M2bUdGc6
N3ec592kD3ZDZopD8p/7DEJ4Y9HiD2971KE9dJeFt0g5QdYg/NA6s/rob8SKunE3vouXsXgx
T7PntgMTzlSdriVZzH81Xwj3QEUxeCp6
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICCzCCAZGgAwIBAgISEdK7ujNu1LzmJGjFDYQdmOhDMAoGCCqGSM49BAMDMEYxCzAJBgNV
BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRwwGgYDVQQDExNHbG9iYWxTaWdu
IFJvb3QgRTQ2MB4XDTE5MDMyMDAwMDAwMFoXDTQ2MDMyMDAwMDAwMFowRjELMAkGA1UEBhMC
QkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExHDAaBgNVBAMTE0dsb2JhbFNpZ24gUm9v
dCBFNDYwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAScDrHPt+ieUnd1NPqlRqetMhkytAepJ8qU
uwzSChDH2omwlwxwEwkBjtjqR+q+soArzfwoDdusvKSGN+1wCAB16pMLey5SnCNoIwZD7JIv
U4Tb+0cUB+hflGddyXqBPCCjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBQxCpCPtsad0kRLgLWi5h+xEk8blTAKBggqhkjOPQQDAwNoADBlAjEA31SQ
7Zvvi5QCkxeCmb6zniz2C5GMn0oUsfZkvLtoURMMA/cVi4RguYv/Uo7njLwcAjA8+RHUjE7A
wWHCFUyqqx0LMV87HOIAl0Qx5v5zli/altP+CAezNIm8BZ/3Hobui3A=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFgjCCA2qgAwIBAgILWku9WvtPilv6ZeUwDQYJKoZIhvcNAQELBQAwTTELMAkGA1UEBhMC
QVQxIzAhBgNVBAoTGmUtY29tbWVyY2UgbW9uaXRvcmluZyBHbWJIMRkwFwYDVQQDExBHTE9C
QUxUUlVTVCAyMDIwMB4XDTIwMDIxMDAwMDAwMFoXDTQwMDYxMDAwMDAwMFowTTELMAkGA1UE
BhMCQVQxIzAhBgNVBAoTGmUtY29tbWVyY2UgbW9uaXRvcmluZyBHbWJIMRkwFwYDVQQDExBH
TE9CQUxUUlVTVCAyMDIwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAri5WrRsc
7/aVj6B3GyvTY4+ETUWiD59bRatZe1E0+eyLinjF3WuvvcTfk0Uev5E4C64OFudBc/jbu9G4
UeDLgztzOG53ig9ZYybNpyrOVPu44sB8R85gfD+yc/LAGbaKkoc1DZAoouQVBGM+uq/ufF7M
potQsjj3QWPKzv9pj2gOlTblzLmMCcpL3TGQlsjMH/1WljTbjhzqLL6FLmPdqqmV0/0plRPw
yJiT2S0WR5ARg6I6IqIoV6Lr/sCMKKCmfecqQjuCgGOlYx8ZzHyyZqjC0203b+J+BlHZRYQf
Es4kUmSFC0iAToexIiIwquuuvuAC4EDosEKAA1GqtH6qRNdDYfOiaxaJSaSjpCuKAsR49GiK
weR6NrFvG5Ybd0mN1MkGco/PU+PcF4UgStyYJ9ORJitHHmkHr96i5OTUawuzXnzUJIBHKWk7
buis/UDr2O1xcSvy6Fgd60GXIsUf1DnQJ4+H4xj04KlGDfV0OoIu0G4skaMxXDtG6nsEEFZe
gB31pWXogvziB4xiRfUg3kZwhqG8k9MedKZssCz3AwyIDMvUclOGvGBG85hqwvG/Q/lwIHfK
N0F5VVJjjVsSn8VoxIidrPIwq7ejMZdnrY8XD2zHc+0klGvIg5rQmjdJBKuxFshsSUktq6HQ
jJLyQUp5ISXbY9e2nKd+Qmn7OmMCAwEAAaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8B
Af8EBAMCAQYwHQYDVR0OBBYEFNwuH9FhN3nkq9XVsxJxaD1qaJwiMB8GA1UdIwQYMBaAFNwu
H9FhN3nkq9XVsxJxaD1qaJwiMA0GCSqGSIb3DQEBCwUAA4ICAQCR8EICaEDuw2jAVC/f7GLD
w56KoDEoqoOOpFaWEhCGVrqXctJUMHytGdUdaG/7FELYjQ7ztdGl4wJCXtzoRlgHNQIw4Lx0
SsFDKv/bGtCwr2zD/cuz9X9tAy5ZVp0tLTWMstZDFyySCstd6IwPS3BD0IL/qMy/pJTAvoe9
iuOTe8aPmxadJ2W8esVCgmxcB9CpwYhgROmYhRZf+I/KARDOJcP5YBugxZfD0yyIMaK9MOzQ
0MAS8cE54+X1+NZK3TTN+2/BT+MAi1bikvcoskJ3ciNnxz8RFbLEAwW+uxF7Cr+obuf/WEPP
m2eggAe2HcqtbepBEX4tdJP7wry+UUTF72glJ4DjyKDUEuzZpTcdN3y0kcra1LGWge9oXHYQ
Sa9+pTeAsRxSvTOBTI/53WXZFM2KJVj04sWDpQmQ1GwUY7VA3+vA/MRYfg0UFodUJ25W5HCE
uGwyEn6CMUO+1918oa2u1qsgEu8KwxCMSZY13At1XrFP1U80DhEgB3VDRemjEdqso5nCtnkn
4rnvyOL2NSl6dPrFf4IFYqYK6miyeUcGbvJXqBUzxvd4Sj1Ce2t+/vdG6tHrju+IaFvowdlx
fv1k7/9nR4hYJS8+hge9+6jlgqispdNpQ80xiEmEU5LAsTkbOYMBMMTyqfrQA71yN2BWHzZ8
vTmR9W0Nv3vXkg==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIF7zCCA9egAwIBAgIIDdPjvGz5a7EwDQYJKoZIhvcNAQELBQAwgYQxEjAQBgNVBAUTCUc2
MzI4NzUxMDELMAkGA1UEBhMCRVMxJzAlBgNVBAoTHkFORiBBdXRvcmlkYWQgZGUgQ2VydGlm
aWNhY2lvbjEUMBIGA1UECxMLQU5GIENBIFJhaXoxIjAgBgNVBAMTGUFORiBTZWN1cmUgU2Vy
dmVyIFJvb3QgQ0EwHhcNMTkwOTA0MTAwMDM4WhcNMzkwODMwMTAwMDM4WjCBhDESMBAGA1UE
BRMJRzYzMjg3NTEwMQswCQYDVQQGEwJFUzEnMCUGA1UEChMeQU5GIEF1dG9yaWRhZCBkZSBD
ZXJ0aWZpY2FjaW9uMRQwEgYDVQQLEwtBTkYgQ0EgUmFpejEiMCAGA1UEAxMZQU5GIFNlY3Vy
ZSBTZXJ2ZXIgUm9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANvrayvm
ZFSVgpCjcqQZAZ2cC4Ffc0m6p6zzBE57lgvsEeBbphzOG9INgxwruJ4dfkUyYA8H6XdYfp9q
yGFOtibBTI3/TO80sh9l2Ll49a2pcbnvT1gdpd50IJeh7WhM3pIXS7yr/2WanvtH2Vdy8wmh
rnZEE26cLUQ5vPnHO6RYPUG9tMJJo8gN0pcvB2VSAKduyK9o7PQUlrZXH1bDOZ8rbeTzPvY1
ZNoMHKGESy9LS+IsJJ1tk0DrtSOOMspvRdOoiXsezx76W0OLzc2oD2rKDF65nkeP8Nm2CgtY
ZRczuSPkdxl9y0oukntPLxB3sY0vaJxizOBQ+OyRp1RMVwnVdmPF6GUe7m1qzwmd+nxPrWAI
/VaZDxUse6mAq4xhj0oHdkLePfTdsiQzW7i1o0TJrH93PB0j7IKppuLIBkwC/qxcmZkLLxCK
pvR/1Yd0DVlJRfbwcVw5Kda/SiOL9V8BY9KHcyi1Swr1+KuCLH5zJTIdC2MKF4EA/7Z2Xue0
sUDKIbvVgFHlSFJnLNJhiQcND85Cd8BEc5xEUKDbEAotlRyBr+Qc5RQe8TZBAQIvfXOn3kLM
TOmJDVb3n5HUA8ZsyY/b2BzgQJhdZpmYgG4t/wHFzstGH6wCxkPmrqKEPMVOHj1tyRRM4y5B
u8o5vzY8KhmqQYdOpc5LMnndkEl/AgMBAAGjYzBhMB8GA1UdIwQYMBaAFJxf0Gxjo1+TypOY
CK2Mh6UsXME3MB0GA1UdDgQWBBScX9BsY6Nfk8qTmAitjIelLFzBNzAOBgNVHQ8BAf8EBAMC
AYYwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEATh65isagmD9uw2nAalxJ
UqzLK114OMHVVISfk/CHGT0sZonrDUL8zPB1hT+L9IBdeeUXZ701guLyPI59WzbLWoAAKfLO
Kyzxj6ptBZNscsdW699QIyjlRRA96Gejrw5VD5AJYu9LWaL2U/HANeQvwSS9eS9OICI7/Rog
sKQOLHDtdD+4E5UGUcjohybKpFtqFiGS3XNgnhAY3jyB6ugYw3yJ8otQPr0R4hUDqDZ9MwFs
SBXXiJCZBMXM5gf0vPSQ7RPi6ovDj6MzD8EpTBNO2hVWcXNyglD2mjN8orGoGjR0ZVzO0eur
U+AagNjqOknkJjCb5RyKqKkVMoaZkgoQI1YS4PbOTOK7vtuNknMBZi9iPrJyJ0U27U1W45eZ
/zo1PqVUSlJZS2Db7v54EX9K3BR5YLZrZAPbFYPhor72I5dQ8AkzNqdxliXzuUJ92zg/LFis
6ELhDtjTO0wugumDLmsx2d1Hhk9tl5EuT+IocTUW0fJz/iUrB0ckYyfI+PbZa/wSMVYIwFNC
r5zQM378BvAxRAMU8Vjq8moNqRGyg77FGr8H6lnco4g175x2MjxNBiLOFeXdntiP2t7SxDnl
F4HPOEfrf4htWRvfn0IUrn7PqLBmZdo3r5+qPeoott7VMVgWglvquxl1AnMaykgaIZOQCo6T
hKd9OyMYkomgjaw=
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIICZTCCAeugAwIBAgIQeI8nXIESUiClBNAt3bpz9DAKBggqhkjOPQQDAzB0MQswCQYDVQQG
EwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMScwJQYDVQQLEx5DZXJ0
dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxGTAXBgNVBAMTEENlcnR1bSBFQy0zODQgQ0Ew
HhcNMTgwMzI2MDcyNDU0WhcNNDMwMzI2MDcyNDU0WjB0MQswCQYDVQQGEwJQTDEhMB8GA1UE
ChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNh
dGlvbiBBdXRob3JpdHkxGTAXBgNVBAMTEENlcnR1bSBFQy0zODQgQ0EwdjAQBgcqhkjOPQIB
BgUrgQQAIgNiAATEKI6rGFtqvm5kN2PkzeyrOvfMobgOgknXhimfoZTy42B4mIF4Bk3y7JoO
V2CDn7TmFy8as10CW4kjPMIRBSqniBMY81CE1700LCeJVf/OTOffph8oxPBUw7l8t1Ot68Kj
QjBAMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFI0GZnQkdjrzife81r1HfS+8EF9LMA4G
A1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNoADBlAjADVS2m5hjEfO/JUG7BJw+ch69u1RsI
GL2SKcHvlJF40jocVYli5RsJHrpka/F2tNQCMQC0QoSZ/6vnnvuRlydd3LBbMHHOXjgaatkl
5+r3YZJW+OraNsKHZZYuciUvf9/DE8k=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFwDCCA6igAwIBAgIQHr9ZULjJgDdMBvfrVU+17TANBgkqhkiG9w0BAQ0FADB6MQswCQYD
VQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMScwJQYDVQQLEx5D
ZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxHzAdBgNVBAMTFkNlcnR1bSBUcnVzdGVk
IFJvb3QgQ0EwHhcNMTgwMzE2MTIxMDEzWhcNNDMwMzE2MTIxMDEzWjB6MQswCQYDVQQGEwJQ
TDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0g
Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkxHzAdBgNVBAMTFkNlcnR1bSBUcnVzdGVkIFJvb3Qg
Q0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDRLY67tzbqbTeRn06TpwXkKQMl
zhyC93yZn0EGze2jusDbCSzBfN8pfktlL5On1AFrAygYo9idBcEq2EXxkd7fO9CAAozPOA/q
p1x4EaTByIVcJdPTsuclzxFUl6s1wB52HO8AU5853BSlLCIls3Jy/I2z5T4IHhQqNwuIPMqw
9MjCoa68wb4pZ1Xi/K1ZXP69VyywkI3C7Te2fJmItdUDmj0VDT06qKhF8JVOJVkdzZhpu9PM
MsmN74H+rX2Ju7pgE8pllWeg8xn2A1bUatMn4qGtg/BKEiJ3HAVz4hlxQsDsdUaakFjgao4r
pUYwBI4Zshfjvqm6f1bxJAPXsiEodg42MEx51UGamqi4NboMOvJEGyCI98Ul1z3G4z5D3Yf+
xOr1Uz5MZf87Sst4WmsXXw3Hw09Omiqi7VdNIuJGmj8PkTQkfVXjjJU30xrwCSss0smNtA0A
q2cpKNgB9RkEth2+dv5yXMSFytKAQd8FqKPVhJBPC/PgP5sZ0jeJP/J7UhyM9uH3PAeXjA6i
WYEMspA90+NZRu0PqafegGtaqge2Gcu8V/OXIXoMsSt0Puvap2ctTMSYnjYJdmZm/Bo/6khU
HL4wvYBQv3y1zgD2DGHZ5yQD4OMBgQ692IU0iL2yNqh7XAjlRICMb/gv1SHKHRzQ+8S1h9E6
Tsd2tTVItQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSM+xx1vALTn04u
SNn5YFSqxLNP+jAOBgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQENBQADggIBAEii1QALLtA/
vBzVtVRJHlpr9OTy4EA34MwUe7nJ+jW1dReTagVphZzNTxl4WxmB82M+w85bj/UvXgF2Ez8s
ALnNllI5SW0ETsXpD4YN4fqzX4IS8TrOZgYkNCvozMrnadyHncI013nR03e4qllY/p0m+jiG
Pp2Kh2RX5Rc64vmNueMzeMGQ2Ljdt4NR5MTMI9UGfOZR0800McD2RrsLrfw9EAUqO0qRJe6M
1ISHgCq8CYyqOhNf6DR5UMEQGfnTKB7U0VEwKbOukGfWHwpjscWpxkIxYxeU72nLL/qMFH3E
QxiJ2fAyQOaA4kZf5ePBAFmo+eggvIksDkc0C+pXwlM2/KfUrzHN/gLldfq5Jwn58/U7yn2f
qSLLiMmq0Uc9NneoWWRrJ8/vJ8HjJLWG965+Mk2weWjROeiQWMODvA8s1pfrzgzhIMfatz7D
P78v3DSk+yshzWePS/Tj6tQ/50+6uaWTRRxmHyH6ZF5v4HaUMst19W7l9o/HuKTMqJZ9ZPsk
WkoDbGs4xugDQ5r3V7mzKWmTOPQD8rv7gmsHINFSH5pkAnuYZttcTVoP0ISVoDwUQwbKytu4
QTbaakRnh6+v40URFWkIsr4WOZckbxJF0WddCajJFdr60qZfE2Efv4WstK2tBZQIgx51F9Nx
O5NQI1mg7TyRVJ12AMXDuDjb
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFszCCA5ugAwIBAgIUEwLV4kBMkkaGFmddtLu7sms+/BMwDQYJKoZIhvcNAQELBQAwYTEL
MAkGA1UEBhMCVE4xNzA1BgNVBAoMLkFnZW5jZSBOYXRpb25hbGUgZGUgQ2VydGlmaWNhdGlv
biBFbGVjdHJvbmlxdWUxGTAXBgNVBAMMEFR1blRydXN0IFJvb3QgQ0EwHhcNMTkwNDI2MDg1
NzU2WhcNNDQwNDI2MDg1NzU2WjBhMQswCQYDVQQGEwJUTjE3MDUGA1UECgwuQWdlbmNlIE5h
dGlvbmFsZSBkZSBDZXJ0aWZpY2F0aW9uIEVsZWN0cm9uaXF1ZTEZMBcGA1UEAwwQVHVuVHJ1
c3QgUm9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMPN0/y9BFPdDCA6
1YguBUtB9YOCfvdZn56eY+hz2vYGqU8ftPkLHzmMmiDQfgbU7DTZhrx1W4eI8NLZ1KMKsmwb
60ksPqxd2JQDoOw05TDENX37Jk0bbjBU2PWARZw5rZzJJQRNmpA+TkBuimvNKWfGzC3gdOgF
VwpIUPp6Q9p+7FuaDmJ2/uqdHYVy7BG7NegfJ7/Boce7SBbdVtfMTqDhuazb1YMZGoXRlJfX
yqNlC/M4+QKu3fZnz8k/9YosRxqZbwUN/dAdgjH8KcwAWJeRTIAAHDOFli/LQcKLEITDCSSJ
H7UP2dl3RxiSlGBcx5kDPP73lad9UKGAwqmDrViWVSHbhlnUr8a83YFuB9tgYv7sEG7aaAH0
gxupPqJbI9dkxt/con3YS7qC0lH4Zr8GRuR5KiY2eY8fTpkdso8MDhz/yV3A/ZAQprE38806
JG60hZC/gLkMjNWb1sjxVj8agIl6qeIbMlEsPvLfe/ZdeikZjuXIvTZxi11Mwh0/rViizz1w
TaZQmCXcI/m4WEEIcb9PuISgjwBUFfyRbVinljvrS5YnzWuioYasDXxU5mZMZl+QviGaAkYt
5IPCgLnPSz7ofzwB7I9ezX/SKEIBlYrilz0QIX32nRzFNKHsLA4KUiwSVXAkPcvCFDVDXSdO
vsC9qnyW5/yeYa1E0wCXAgMBAAGjYzBhMB0GA1UdDgQWBBQGmpsfU33x9aTI04Y+oXNZtPdE
ITAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFAaamx9TffH1pMjThj6hc1m090QhMA4G
A1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAqgVutt0Vyb+zxiD2BkewhpMl0425
yAA/l/VSJ4hxyXT968pk21vvHl26v9Hr7lxpuhbI87mP0zYuQEkHDVneixCwSQXi/5E/S7fd
Ao74gShczNxtr18UnH1YeA32gAm56Q6XKRm4t+v4FstVEuTGfbvE7Pi1HE4+Z7/FXxttbUco
qgRYYdZ2vyJ/0Adqp2RT8JeNnYA/u8EH22Wv5psymsNUk8QcCMNE+3tjEUPRahphanltkE8p
jkcFwRJpadbGNjHh/PqAulxPxOu3Mqz4dWEX1xAZufHSCe96Qp1bWgvUxpVOKs7/B9dPfhgG
iPEZtdmYu65xxBzndFlY7wyJz4sfdZMaBBSSSFCp61cpABbjNhzI+L/wM9VBD8TMPN3pM0MB
kRArHtG5Xc0yGYuPjCB31yLEQtyEFpslbei0VXF/sHyz03FJuc9SpAQ/3D2gu68zngowYI7b
nV2UqL1g52KAdoGDDIzMMEZJ4gzSqK/rYXHv5yJiqfdcZGyfFoxnNidF9Ql7v/YQCvGwjVRD
jAS6oz/v4jXH+XTgbzRB0L9zZVcg+ZtnemZoJE6AZb0QmQZZ8mWvuMZHu/2QeItBcy6vVR/c
O5JyboTT0GFMDcx2V+IthSIVNg3rAZ3r2OvEhJn7wAzMMujjd9qDRIueVSjAi1jTkD5OGwDx
Fa2DK5o=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIFpDCCA4ygAwIBAgIQOcqTHO9D88aOk8f0ZIk4fjANBgkqhkiG9w0BAQsFADBsMQswCQYD
VQQGEwJHUjE3MDUGA1UECgwuSGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2VhcmNoIEluc3Rp
dHV0aW9ucyBDQTEkMCIGA1UEAwwbSEFSSUNBIFRMUyBSU0EgUm9vdCBDQSAyMDIxMB4XDTIx
MDIxOTEwNTUzOFoXDTQ1MDIxMzEwNTUzN1owbDELMAkGA1UEBhMCR1IxNzA1BgNVBAoMLkhl
bGxlbmljIEFjYWRlbWljIGFuZCBSZXNlYXJjaCBJbnN0aXR1dGlvbnMgQ0ExJDAiBgNVBAMM
G0hBUklDQSBUTFMgUlNBIFJvb3QgQ0EgMjAyMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
AgoCggIBAIvC569lmwVnlskNJLnQDmT8zuIkGCyEf3dRywQRNrhe7Wlxp57kJQmXZ8FHws+R
FjZiPTgE4VGC/6zStGndLuwRo0Xua2s7TL+MjaQenRG56Tj5eg4MmOIjHdFOY9TnuEFE+2uv
a9of08WRiFukiZLRgeaMOVig1mlDqa2YUlhu2wr7a89o+uOkXjpFc5gH6l8Cct4MpbOfrqkd
tx2z/IpZ525yZa31MJQjB/OCFks1mJxTuy/K5FrZx40d/JiZ+yykgmvwKh+OC19xXFyuQnsp
iYHLA6OZyoieC0AJQTPb5lh6/a6ZcMBaD9YThnEvdmn8kN3bLW7R8pv1GmuebxWMevBLKKAi
OIAkbDakO/IwkfN4E8/BPzWr8R0RI7VDIp4BkrcYAuUR0YLbFQDMYTfBKnya4dC6s1BG7oKs
nTH4+yPiAwBIcKMJJnkVU2DzOFytOOqBAGMUuTNe3QvboEUHGjMJ+E20pwKmafTCWQWIZYVW
rkvL4N48fS0ayOn7H6NhStYqE613TBoYm5EPWNgGVMWX+Ko/IIqmhaZ39qb8HOLubpQzKoNQ
hArlT4b4UEV4AIHrW2jjJo3Me1xR9BQsQL4aYB16cmEdH2MtiKrOokWQCPxrvrNQKlr9qEgY
RtaQQJKQCoReaDH46+0N0x3GfZkYVVYnZS6NRcUk7M7jAgMBAAGjQjBAMA8GA1UdEwEB/wQF
MAMBAf8wHQYDVR0OBBYEFApII6ZgpJIKM+qTW8VX6iVNvRLuMA4GA1UdDwEB/wQEAwIBhjAN
BgkqhkiG9w0BAQsFAAOCAgEAPpBIqm5iFSVmewzVjIuJndftTgfvnNAUX15QvWiWkKQUEapo
bQk1OUAJ2vQJLDSle1mESSmXdMgHHkdt8s4cUCbjnj1AUz/3f5Z2EMVGpdAgS1D0NTsY9FVq
QRtHBmg8uwkIYtlfVUKqrFOFrJVWNlar5AWMxajaH6NpvVMPxP/cyuN+8kyIhkdGGvMA9YCR
otxDQpSbIPDRzbLrLFPCU3hKTwSUQZqPJzLB5UkZv/HywouoCjkxKLR9YjYsTewfM7Z+d21+
UPCfDtcRj88YxeMn/ibvBZ3PzzfF0HvaO7AWhAw6k9a+F9sPPg4ZeAnHqQJyIkv3N3a6dcSF
A1pj1bF1BcK5vZStjBWZp5N99sXzqnTPBIWUmAD04vnKJGW/4GKvyMX6ssmeVkjaef2WdhW+
o45WxLM0/L5H9MG0qPzVMIho7suuyWPEdr6sOBjhXlzPrjoiUevRi7PzKzMHVIf6tLITe7pT
BGIBnfHAT+7hOtSLIBD6Alfm78ELt5BGnBkpjNxvoEppaZS3JGWg/6w/zgH7IS79aPib8qXP
MThcFarmlwDB31qlpzmq6YR/PFGoOtmUW4y/Twhx5duoXNTSpv4Ao8YWxw/ogM4cKGR0GQjT
QuPOAF1/sdwTsOEFy9EgqoZ0njnnkf3/W9b3raYvAwtt41dU63ZTGI0RmLo=
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIICVDCCAdugAwIBAgIQZ3SdjXfYO2rbIvT/WeK/zjAKBggqhkjOPQQDAzBsMQswCQYDVQQG
EwJHUjE3MDUGA1UECgwuSGVsbGVuaWMgQWNhZGVtaWMgYW5kIFJlc2VhcmNoIEluc3RpdHV0
aW9ucyBDQTEkMCIGA1UEAwwbSEFSSUNBIFRMUyBFQ0MgUm9vdCBDQSAyMDIxMB4XDTIxMDIx
OTExMDExMFoXDTQ1MDIxMzExMDEwOVowbDELMAkGA1UEBhMCR1IxNzA1BgNVBAoMLkhlbGxl
bmljIEFjYWRlbWljIGFuZCBSZXNlYXJjaCBJbnN0aXR1dGlvbnMgQ0ExJDAiBgNVBAMMG0hB
UklDQSBUTFMgRUNDIFJvb3QgQ0EgMjAyMTB2MBAGByqGSM49AgEGBSuBBAAiA2IABDgI/rGg
ltJ6rK9JOtDA4MM7KKrxcm1lAEeIhPyaJmuqS7psBAqIXhfyVYf8MLA04jRYVxqEU+kw2any
lnTDUR9YSTHMmE5gEYd103KUkE+bECUqqHgtvpBBWJAVcqeht6NCMEAwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUyRtTgRL+BNUW0aq8mm+3oJUZbsowDgYDVR0PAQH/BAQDAgGGMAoG
CCqGSM49BAMDA2cAMGQCMBHervjcToiwqfAircJRQO9gcS3ujwLEXQNwSaSS6sUUiHCm0w2w
qsosQJz76YJumgIwK0eaB8bRwoF8yguWGEEbo/QwCZ61IygNnxS2PFOiTAZpffpskcYqSUXm
7LcT4Tps
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIIGFDCCA/ygAwIBAgIIG3Dp0v+ubHEwDQYJKoZIhvcNAQELBQAwUTELMAkGA1UEBhMCRVMx
QjBABgNVBAMMOUF1dG9yaWRhZCBkZSBDZXJ0aWZpY2FjaW9uIEZpcm1hcHJvZmVzaW9uYWwg
Q0lGIEE2MjYzNDA2ODAeFw0xNDA5MjMxNTIyMDdaFw0zNjA1MDUxNTIyMDdaMFExCzAJBgNV
BAYTAkVTMUIwQAYDVQQDDDlBdXRvcmlkYWQgZGUgQ2VydGlmaWNhY2lvbiBGaXJtYXByb2Zl
c2lvbmFsIENJRiBBNjI2MzQwNjgwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDK
lmuO6vj78aI14H9M2uDDUtd9thDIAl6zQyrET2qyyhxdKJp4ERppWVevtSBC5IsP5t9bpgOS
L/UR5GLXMnE42QQMcas9UX4PB99jBVzpv5RvwSmCwLTaUbDBPLutN0pcyvFLNg4kq7/DhHf9
qFD0sefGL9ItWY16Ck6WaVICqjaY7Pz6FIMMNx/Jkjd/14Et5cS54D40/mf0PmbR0/RAz15i
NA9wBj4gGFrO93IbJWyTdBSTo3OxDqqHECNZXyAFGUftaI6SEspd/NYrspI8IM/hX68gvqB2
f3bl7BqGYTM+53u0P6APjqK5am+5hyZvQWyIplD9amML9ZMWGxmPsu2bm8mQ9QEM3xk9Dz44
I8kvjwzRAv4bVdZO0I08r0+k8/6vKtMFnXkIoctXMbScyJCyZ/QYFpM6/EfY0XiWMR+6Kwxf
XZmtY4laJCB22N/9q06mIqqdXuYnin1oKaPnirjaEbsXLZmdEyRG98Xi2J+Of8ePdG1asuhy
9azuJBCtLxTa/y2aRnFHvkLfuwHb9H/TKI8xWVvTyQKmtFLKbpf7Q8UIJm+K9Lv9nyiqDdVF
8xM6HdjAeI9BZzwelGSuewvF6NkBiDkal4ZkQdU7hwxu+g/GvUgUvzlN1J5Bto+WHWOWk9mV
BngxaJ43BjuAiUVhOSPHG0SjFeUc+JIwuwIDAQABo4HvMIHsMB0GA1UdDgQWBBRlzeurNR4A
Pn7VdMActHNHDhpkLzASBgNVHRMBAf8ECDAGAQH/AgEBMIGmBgNVHSAEgZ4wgZswgZgGBFUd
IAAwgY8wLwYIKwYBBQUHAgEWI2h0dHA6Ly93d3cuZmlybWFwcm9mZXNpb25hbC5jb20vY3Bz
MFwGCCsGAQUFBwICMFAeTgBQAGEAcwBlAG8AIABkAGUAIABsAGEAIABCAG8AbgBhAG4AbwB2
AGEAIAA0ADcAIABCAGEAcgBjAGUAbABvAG4AYQAgADAAOAAwADEANzAOBgNVHQ8BAf8EBAMC
AQYwDQYJKoZIhvcNAQELBQADggIBAHSHKAIrdx9miWTtj3QuRhy7qPj4Cx2Dtjqn6EWKB7fg
PiDL4QjbEwj4KKE1soCzC1HA01aajTNFSa9J8OA9B3pFE1r/yJfY0xgsfZb43aJlQ3CTkBW6
kN/oGbDbLIpgD7dvlAceHabJhfa9NPhAeGIQcDq+fUs5gakQ1JZBu/hfHAsdCPKxsIl68veg
4MSPi3i1O1ilI45PVf42O+AMt8oqMEEgtIDNrvx2ZnOorm7hfNoD6JQg5iKj0B+QXSBTFCZX
2lSX3xZEEAEeiGaPcjiT3SC3NL7X8e5jjkd5KAb881lFJWAiMxujX6i6KtoaPc1A6ozuBRWV
1aUsIC+nmCjuRfzxuIgALI9C2lHVnOUTaHFFQ4ueCyE8S1wF3BqfmI7avSKecs2tCsvMo2eb
KHTEm9caPARYpoKdrcd7b/+Alun4jWq9GJAd/0kakFI3ky88Al2CdgtR5xbHV/g4+afNmyJU
72OwFW1TZQNKXkqgsqeOSQBZONXH9IBk9W6VULgRfhVwOEqwf9DEMnDAGf/JOC0ULGb0QkTm
VXYbgBVX/8Cnp6o5qtjTcNAuuuuUavpfNIbnYrX9ivAwhZTJryQCL2/W3Wf+47BVTwSYT6RB
VuKT0Gro1vP7ZeDOdcQxWQzugsgMYDNKGbqEZycPvEJdvSRUDewdcAZfpLz6IHxV
-----END CERTIFICATE-----      -----BEGIN CERTIFICATE-----
MIICDzCCAZWgAwIBAgIUbmq8WapTvpg5Z6LSa6Q75m0c1towCgYIKoZIzj0EAwMwRzELMAkG
A1UEBhMCQ04xHDAaBgNVBAoTE2lUcnVzQ2hpbmEgQ28uLEx0ZC4xGjAYBgNVBAMTEXZUcnVz
IEVDQyBSb290IENBMB4XDTE4MDczMTA3MjY0NFoXDTQzMDczMTA3MjY0NFowRzELMAkGA1UE
BhMCQ04xHDAaBgNVBAoTE2lUcnVzQ2hpbmEgQ28uLEx0ZC4xGjAYBgNVBAMTEXZUcnVzIEVD
QyBSb290IENBMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEZVBKrox5lkqqHAjDo6LN/llWQXf9
JpRCux3NCNtzslt188+cToL0v/hhJoVs1oVbcnDS/dtitN9Ti72xRFhiQgnH+n9bEOf+QP3A
2MMrMudwpremIFUde4BdS49nTPEQo0IwQDAdBgNVHQ4EFgQUmDnNvtiyjPeyq+GtJK97fKHb
H88wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwMDaAAwZQIw
V53dVvHH4+m4SVBrm2nDb+zDfSXkV5UTQJtS0zvzQBm8JsctBp61ezaf9SXUY2sAAjEA6dPG
nlaaKsyh2j/IZivTWJwghfqrkYpwcBE4YGQLYgmRWAD5Tfs0aNoJrSEGGJTO
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFVjCCAz6gAwIBAgIUQ+NxE9izWRRdt86M/TX9b7wFjUUwDQYJKoZIhvcNAQELBQAwQzEL
MAkGA1UEBhMCQ04xHDAaBgNVBAoTE2lUcnVzQ2hpbmEgQ28uLEx0ZC4xFjAUBgNVBAMTDXZU
cnVzIFJvb3QgQ0EwHhcNMTgwNzMxMDcyNDA1WhcNNDMwNzMxMDcyNDA1WjBDMQswCQYDVQQG
EwJDTjEcMBoGA1UEChMTaVRydXNDaGluYSBDby4sTHRkLjEWMBQGA1UEAxMNdlRydXMgUm9v
dCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL1VfGHTuB0EYgWgrmy3cLRB
6ksDXhA/kFocizuwZotsSKYcIrrVQJLuM7IjWcmOvFjai57QGfIvWcaMY1q6n6MLsLOaXLoR
uBLpDLvPbmyAhykUAyyNJJrIZIO1aqwTLDPxn9wsYTwaP3BVm60AUn/PBLn+NvqcwBauYv6W
TEN+VRS+GrPSbcKvdmaVayqwlHeFXgQPYh1jdfdr58tbmnDsPmcF8P4HCIDPKNsFxhQnL4Z9
8Cfe/+Z+M0jnCx5Y0ScrUw5XSmXX+6KAYPxMvDVTAWqXcoKv8R1w6Jz1717CbMdHflqUhSZN
O7rrTOiwCcJlwp2dCZtOtZcFrPUGoPc2BX70kLJrxLT5ZOrpGgrIDajtJ8nU57O5q4IikCc9
Kuh8kO+8T/3iCiSn3mUkpF3qwHYw03dQ+A0Em5Q2AXPKBlim0zvc+gRGE1WKyURHuFE5Gi7o
NOJ5y1lKCn+8pu8fA2dqWSslYpPZUxlmPCdiKYZNpGvu/9ROutW04o5IWgAZCfEF2c6Rsffr
6TlP9m8EQ5pV9T4FFL2/s1m02I4zhKOQUqqzApVg+QxMaPnu1RcN+HFXtSXkKe5lXa/R7jwX
C1pDxaWG6iSe4gUH3DRCEpHWOXSuTEGC2/KmSNGzm/MzqvOmwMVO9fSddmPmAsYiS8GVP1Bk
LFTltvA8Kc9XAgMBAAGjQjBAMB0GA1UdDgQWBBRUYnBj8XWEQ1iO0RYgscasGrz2iTAPBgNV
HRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAKbqSSaet
8PFww+SX8J+pJdVrnjT+5hpk9jprUrIQeBqfTNqK2uwcN1LgQkv7bHbKJAs5EhWdnxEt/Hlk
3ODg9d3gV8mlsnZwUKT+twpw1aA08XXXTUm6EdGz2OyC/+sOxL9kLX1jbhd47F18iMjrjld2
2VkE+rxSH0Ws8HqA7Oxvdq6R2xCOBNyS36D25q5J08FsEhvMKar5CKXiNxTKsbhm7xqC5PD4
8acWabfbqWE8n/Uxy+QARsIvdLGx14HuqCaVvIivTDUHKgLKeBRtRytAVunLKmChZwOgzoy8
sHJnxDHO2zTlJQNgJXtxmOTAGytfdELSS8VZCAeHvsXDf+eW2eHcKJfWjwXj9ZtOyh1QRwVT
sMo554WgicEFOwE30z9J4nfrI8iIZjs9OXYhRvHsXyO466JmdXTBQPfYaJqT4i2pLr0cox7I
dMakLXogqzu4sEb9b91fUlV1YvCXoHzXOP0l382gmxDPi7g4Xl7FtKYCNqEeXxzP4padKar9
mK5S4fNBUvupLnKWnyfjqnN9+BojZns7q2WwMgFLFT49ok8MKzWixtlnEjUwzXYuFrOZnk1P
Ti07NEPhmg4NpGaXutIcSkwsKouLgU9xGqndXHt7CMUADTdA43x7VF8vhV929vensBxXVsFy
6K2ir40zSbofitzmdHxghm+Hl3s=
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIICGzCCAaGgAwIBAgIQQdKd0XLq7qeAwSxs6S+HUjAKBggqhkjOPQQDAzBPMQswCQYDVQQG
EwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNV
BAMTDElTUkcgUm9vdCBYMjAeFw0yMDA5MDQwMDAwMDBaFw00MDA5MTcxNjAwMDBaME8xCzAJ
BgNVBAYTAlVTMSkwJwYDVQQKEyBJbnRlcm5ldCBTZWN1cml0eSBSZXNlYXJjaCBHcm91cDEV
MBMGA1UEAxMMSVNSRyBSb290IFgyMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEzZvVn4CDCuwJ
SvMWSj5cz3es3mcFDR0HttwW+1qLFNvicWDEukWVEYmO6gbf9yoWHKS5xcUy4APgHoIYOIvX
RdgKam7mAHf7AlF9ItgKbppbd9/w+kHsOdx1ymgHDB/qo0IwQDAOBgNVHQ8BAf8EBAMCAQYw
DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUfEKWrt5LSDv6kviejM9ti6lyN5UwCgYIKoZI
zj0EAwMDaAAwZQIwe3lORlCEwkSHRhtFcP9Ymd70/aTSVaYgLXTWNLxBo1BfASdWtL4ndQav
Ei51mI38AjEAi/V3bNTIZargCyzuFJ0nN6T5U6VR5CmD1/iQMVtCnwr1/q4AaOeMSQ+2b1tb
FfLn
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIFajCCA1KgAwIBAgIQLd2szmKXlKFD6LDNdmpeYDANBgkqhkiG9w0BAQsFADBPMQswCQYD
VQQGEwJUVzEjMCEGA1UECgwaQ2h1bmdod2EgVGVsZWNvbSBDby4sIEx0ZC4xGzAZBgNVBAMM
EkhpUEtJIFJvb3QgQ0EgLSBHMTAeFw0xOTAyMjIwOTQ2MDRaFw0zNzEyMzExNTU5NTlaME8x
CzAJBgNVBAYTAlRXMSMwIQYDVQQKDBpDaHVuZ2h3YSBUZWxlY29tIENvLiwgTHRkLjEbMBkG
A1UEAwwSSGlQS0kgUm9vdCBDQSAtIEcxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
AgEA9B5/UnMyDHPkvRN0o9QwqNCuS9i233VHZvR85zkEHmpwINJaR3JnVfSl6J3VHiGh8Ge6
zCFovkRTv4354twvVcg3Px+kwJyz5HdcoEb+d/oaoDjq7Zpy3iu9lFc6uux55199QmQ5eiY2
9yTw1S+6lZgRZq2XNdZ1AYDgr/SEYYwNHl98h5ZeQa/rh+r4XfEuiAU+TCK72h8q3VJGZDnz
Qs7ZngyzsHeXZJzA9KMuH5UHsBffMNsAGJZMoYFL3QRtU6M9/Aes1MU3guvklQgZKILSQjqj
2FPseYlgSGDIcpJQ3AOPgz+yQlda22rpEZfdhSi8MEyr48KxRURHH+CKFgeW0iEPU8DtqX7U
TuybCeyvQqww1r/REEXgphaypcXTT3OUM3ECoWqj1jOXTyFjHluP2cFeRXF3D4FdXyGarYPM
+l7WjSNfGz1BryB1ZlpK9p/7qxj3ccC2HTHsOyDry+K49a6SsvfhhEvyovKTmiKe0xRvNlS9
H15ZFblzqMF8b3ti6RZsR1pl8w4Rm0bZ/W3c1pzAtH2lsN0/Vm+h+fbkEkj9Bn8SV7apI09b
A8PgcSojt/ewsTu8mL3WmKgMa/aOEmem8rJY5AIJEzypuxC00jBF8ez3ABHfZfjcK0NVvxaX
xA/VLGGEqnKG/uY6fsI/fe78LxQ+5oXdUG+3Se0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB
/zAdBgNVHQ4EFgQU8ncX+l6o/vY9cdVouslGDDjYr7AwDgYDVR0PAQH/BAQDAgGGMA0GCSqG
SIb3DQEBCwUAA4ICAQBQUfB13HAE4/+qddRxosuej6ip0691x1TPOhwEmSKsxBHi7zNKpiMd
Dg1H2DfHb680f0+BazVP6XKlMeJ45/dOlBhbQH3PayFUhuaVevvGyuqcSE5XCV0vrPSltJcz
WNWseanMX/mF+lLFjfiRFOs6DRfQUsJ748JzjkZ4Bjgs6FzaZsT0pPBWGTMpWmWSBUdGSquE
wx4noR8RkpkndZMPvDY7l1ePJlsMu5wP1G4wB9TcXzZoZjmDlicmisjEOf6aIW/Vcobpf2Ll
l07QJNBAsNB1CI69aO4I1258EHBGG3zgiLKecoaZAeO/n0kZtCW+VmWuF2PlHt/o/0elv+Em
BYTksMCv5wiZqAxeJoBF1PhoL5aPruJKHJwWDBNvOIf2u8g0X5IDUXlwpt/L9ZlNec1OvFef
Q05rLisY+GpzjLrFNe85akEez3GoorKGB1s6yeHvP2UEgEcyRHCVTjFnanRbEEV16rCf0OY1
/k6fi8wrkkVbbiVghUbN0aqwdmaTd5a+g744tiROJgvM7XpWGuDpWsZkrUx6AEhEL7lAuxM+
vhV4nYWBSipX3tUZQ9rbyltHhoMLP7YNdnhzeSJesYAfz77RP1YQmCuVh6EfnWQUYDksswBV
LuT1sw5XxJFBAJw/6KXf6vb/yPCtbVKoF6ubYfwSUTXkJf2vqmqGOQ==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIB3DCCAYOgAwIBAgINAgPlfvU/k/2lCSGypjAKBggqhkjOPQQDAjBQMSQwIgYDVQQLExtH
bG9iYWxTaWduIEVDQyBSb290IENBIC0gUjQxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNV
BAMTCkdsb2JhbFNpZ24wHhcNMTIxMTEzMDAwMDAwWhcNMzgwMTE5MDMxNDA3WjBQMSQwIgYD
VQQLExtHbG9iYWxTaWduIEVDQyBSb290IENBIC0gUjQxEzARBgNVBAoTCkdsb2JhbFNpZ24x
EzARBgNVBAMTCkdsb2JhbFNpZ24wWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAS4xnnTj2wl
Dp8uORkcA6SumuU5BwkWymOxuYb4ilfBV85C+nOh92VC/x7BALJucw7/xyHlGKSq2XE/qNS5
zowdo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUVLB7
rUW44kB/+wpu+74zyTyjhNUwCgYIKoZIzj0EAwIDRwAwRAIgIk90crlgr/HmnKAWBVBfw147
bmF0774BxL4YSFlhgjICICadVGNA3jdgUM/I2O2dgq43mLyjj0xMqTQrbO/7lZsm
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQswCQYDVQQG
EwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RT
IFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAwWjBHMQswCQYDVQQGEwJV
UzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJv
b3QgUjEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreV
p0A8of2C+X0yBoJx9vaMf/vo27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4
IyfLpLGcY9vXmX7wCl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/S
CYe7zUjwTcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl
qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaHszVsrBhQ
f4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8Y/kB+Xj9e1x3+naH
+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmkMiVOKvFlRNACzqrOSbTqn3yD
sEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97
PtbfkSIS5r762DL8EGMUUXLeXdYWk70paDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmx
lbCluQ0WEdrHbEg8QOB+DVrNVjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACY
PTrIrnqYNxgFlQIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAd
BgNVHQ4EFgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb
C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEeQkEzCzc9
zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuyh6f88/qBVRRiClmp
IgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM47HLwEXWdyzRSjeZ2axfG34ar
J45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8JZgfIPxz88NtFMN9iiMG1D53Dn0reWVlH
xYciNuaCp+0KueIHoI17eko8cdLiA6EfMgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/b
al8xa5meLMFrUKTX5hgUvYU/Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAb
d03OIozUhfJFfbdT6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLs
QBqvFAnZ0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm
2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bbbP6MvPJw
NQzcmRk13NfIRmPVNnGuV/u3gm3c
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlrsWNBCUaqxElqjANBgkqhkiG9w0BAQwFADBHMQswCQYDVQQG
EwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RT
IFJvb3QgUjIwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAwWjBHMQswCQYDVQQGEwJV
UzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJv
b3QgUjIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDO3v2m++zsFDQ8BwZabFn3
GTXd98GdVarTzTukk3LvCvptnfbwhYBboUhSnznFt+4orO/LdmgUud+tAWyZH8QiHZ/+cnfg
LFuv5AS/T3KgGjSY6Dlo7JUle3ah5mm5hRm9iYz+re026nO8/4Piy33B0s5Ks40FnotJk9/B
W9BuXvAuMC6C/Pq8tBcKSOWIm8Wba96wyrQD8Nr0kLhlZPdcTK3ofmZemde4wj7I0BOdre7k
RXuJVfeKH2JShBKzwkCX44ofR5GmdFrS+LFjKBC4swm4VndAoiaYecb+3yXuPuWgf9RhD1FL
PD+M2uFwdNjCaKH5wQzpoeJ/u1U8dgbuak7MkogwTZq9TwtImoS1mKPV+3PBV2HdKFZ1E66H
jucMUQkQdYhMvI35ezzUIkgfKtzra7tEscszcTJGr61K8YzodDqs5xoic4DSMPclQsciOzsS
rZYuxsN2B6ogtzVJV+mSSeh2FnIxZyuWfoqjx5RWIr9qS34BIbIjMt/kmkRtWVtd9QCgHJvG
eJeNkP+byKq0rxFROV7Z+2et1VsRnTKaG73VululycslaVNVJ1zgyjbLiGH7HrfQy+4W+9Om
TN6SpdTi3/UGVN4unUu0kzCqgc7dGtxRcw1PcOnlthYhGXmy5okLdWTK1au8CcEYof/UVKGF
PP0UJAOyh9OktwIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAd
BgNVHQ4EFgQUu//KjiOfT5nK2+JopqUVJxce2Q4wDQYJKoZIhvcNAQEMBQADggIBAB/Kzt3H
vqGf2SdMC9wXmBFqiN495nFWcrKeGk6c1SuYJF2ba3uwM4IJvd8lRuqYnrYb/oM80mJhwQTt
zuDFycgTE1XnqGOtjHsB/ncw4c5omwX4Eu55MaBBRTUoCnGkJE+M3DyCB19m3H0Q/gxhswWV
7uGugQ+o+MePTagjAiZrHYNSVc61LwDKgEDg4XSsYPWHgJ2uNmSRXbBoGOqKYcl3qJfEycel
/FVL8/B/uWU9J2jQzGv6U53hkRrJXRqWbTKH7QMgyALOWr7Z6v2yTcQvG99fevX4i8buMTol
UVVnjWQye+mew4K6Ki3pHrTgSAai/GevHyICc/sgCq+dVEuhzf9gR7A/Xe8bVr2XIZYtCtFe
nTgCR2y59PYjJbigapordwj6xLEokCZYCDzifqrXPW+6MYgKBesntaFJ7qBFVHvmJ2WZICGo
o7z7GJa7Um8M7YNRTOlZ4iBgxcJlkoKM8xAfDoqXvneCbT+PHV28SSe9zE8P4c52hgQjxcCM
Elv924SgJPFI/2R80L5cFtHvma3AH/vLrrw4IgYmZNralw4/KBVEqE8AyvCazM90arQ+POuV
7LXTWtiBmelDGDfrs7vRWGJB82bSj6p4lVQgw1oudCvV0b4YacCs1aTPObpRhANl6WLAYv7Y
TVWW4tAR+kg0Eeye7QUd5MjWHYbL
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPluILrIPglJ209ZjAKBggqhkjOPQQDAzBHMQswCQYDVQQGEwJV
UzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJv
b3QgUjMwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzEi
MCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3Qg
UjMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQfTzOHMymKoYTey8chWEGJ6ladK0uFxh1MJ7x/
JlFyb+Kf1qPKzEUURout736GjOyxfi//qXGdGIRFBEFVbivqJn+7kAHjSxm65FSWRQmx1WyR
RK2EE46ajA2ADDL24CejQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0G
A1UdDgQWBBTB8Sa6oC2uhYHP0/EqEr24Cmf9vDAKBggqhkjOPQQDAwNpADBmAjEA9uEglRR7
VKOQFhG/hMjqb2sXnh5GmCCbn9MN2azTL818+FsuVbu/3ZL3pAzcMeGiAjEA/JdmZuVDFhOD
3cffL74UOO0BzrEXGhF16b0DjyZ+hOXJYKaV11RZt+cRLInUue4X
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYDVQQGEwJV
UzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJv
b3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzEi
MCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3Qg
UjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvV
YRg1rkDdc/eJkTBa6zzuhXyiQHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHc
i8nHc8iMai/lxKvRHYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0G
A1UdDgQWBBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8p/SgguMh
1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFdDCCA1ygAwIBAgIPAWdfJ9b+euPkrL4JWwWeMA0GCSqGSIb3DQEBCwUAMEQxCzAJBgNV
BAYTAkZJMRowGAYDVQQKDBFUZWxpYSBGaW5sYW5kIE95ajEZMBcGA1UEAwwQVGVsaWEgUm9v
dCBDQSB2MjAeFw0xODExMjkxMTU1NTRaFw00MzExMjkxMTU1NTRaMEQxCzAJBgNVBAYTAkZJ
MRowGAYDVQQKDBFUZWxpYSBGaW5sYW5kIE95ajEZMBcGA1UEAwwQVGVsaWEgUm9vdCBDQSB2
MjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALLQPwe84nvQa5n44ndp586dpAO8
gm2h/oFlH0wnrI4AuhZ76zBqAMCzdGh+sq/H1WKzej9Qyow2RCRj0jbpDIX2Q3bVTKFgcmfi
KDOlyzG4OiIjNLh9vVYiQJ3q9HsDrWj8soFPmNB06o3lfc1jw6P23pLCWBnglrvFxKk9pXSW
/q/5iaq9lRdU2HhE8Qx3FZLgmEKnpNaqIJLNwaCzlrI6hEKNfdWV5Nbb6WLEWLN5xYzTNTOD
n3WhUidhOPFZPY5Q4L15POdslv5e2QJltI5c0BE0312/UqeBAMN/mUWZFdUXyApT7GPzmX3M
aRKGwhfwAZ6/hLzRUssbkmbOpFPlob/E2wnW5olWK8jjfN7j/4nlNW4o6GwLI1GpJQXrSPjd
scr6bAhR77cYbETKJuFzxokGgeWKrLDiKca5JLNrRBH0pUPCTEPlcDaMtjNXepUugqD0XBCz
YYP2AgWGLnwtbNwDRm41k9V6lS/eINhbfpSQBGq6WT0EBXWdN6IOLj3rwaRSg/7Qa9RmjtzG
6RJOHSpXqhC8fF6CfaamyfItufUXJ63RDolUK5X6wK0dmBR4M0KGCqlztft0DbcbMBnEWg4c
J7faGND/isgFuvGqHKI3t+ZIpEYslOqodmJHixBTB0hXbOKSTbauBcvcwUpej6w9GU7C7WB1
K9vBykLVAgMBAAGjYzBhMB8GA1UdIwQYMBaAFHKs5DN5qkWH9v2sHZ7Wxy+G2CQ5MB0GA1Ud
DgQWBBRyrOQzeapFh/b9rB2e1scvhtgkOTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAoDtZpwmUPjaE0n4vOaWWl/oRrfxn83EJ8rKJhGdE
r7nv7ZbsnGTbMjBvZ5qsfl+yqwE2foH65IRe0qw24GtixX1LDoJt0nZi0f6X+J8wfBj5tFJ3
gh1229MdqfDBmgC9bXXYfef6xzijnHDoRnkDry5023X4blMMA8iZGok1GTzTyVR8qPAs5m4H
eW9q4ebqkYJpCh3DflminmtGFZhb069GHWLIzoBSSRE/yQQSwxN8PzuKlts8oB4KtItUsiRn
De+Cy748fdHif64W1lZYudogsYMVoe+KTTJvQS8TUoKU1xrBeKJR3Stwbbca+few4GeXVtt8
YVMJAygCQMez2P2ccGrGKMOF6eLtGpOg3kuYooQ+BXcBlj37tCAPnHICehIv1aO6UXivKitE
ZU61/Qrowc15h2Er3oBXRb9n8ZuRXqWk7FlIEA04x7D6w0RtBPV4UBySllva9bguulvP5fBq
nUsvWHMtTy3EHD70sz+rFQ47GUGKpMFXEmZxTPpT41frYpUJnlTd0cI8Vzy9OK2YZLe4A5pT
VmBds9hCG1xLEooc6+t9xnppxyd/pPiL8uSUZodL6ZQHCRJ5irLrdATczvREWeAWysUsWNc8
e89ihmpQfTU2Zqf7N+cox9jQraVplI/owd8k+BsHMYeB2F326CjYSlKArBPuUBQemMc=
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIC2zCCAmCgAwIBAgIQfMmPK4TX3+oPyWWa00tNljAKBggqhkjOPQQDAzBIMQswCQYDVQQG
EwJERTEVMBMGA1UEChMMRC1UcnVzdCBHbWJIMSIwIAYDVQQDExlELVRSVVNUIEJSIFJvb3Qg
Q0EgMSAyMDIwMB4XDTIwMDIxMTA5NDUwMFoXDTM1MDIxMTA5NDQ1OVowSDELMAkGA1UEBhMC
REUxFTATBgNVBAoTDEQtVHJ1c3QgR21iSDEiMCAGA1UEAxMZRC1UUlVTVCBCUiBSb290IENB
IDEgMjAyMDB2MBAGByqGSM49AgEGBSuBBAAiA2IABMbLxyjR+4T1mu9CFCDhQ2tuda38KwOE
1HaTJddZO0Flax7mNCq7dPYSzuht56vkPE4/RAiLzRZxy7+SmfSk1zxQVFKQhYN4lGdnoxwJ
GT11NIXe7WB9xwy0QVK5buXuQqOCAQ0wggEJMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
FHOREKv/VbNafAkl1bK6CKBrqx9tMA4GA1UdDwEB/wQEAwIBBjCBxgYDVR0fBIG+MIG7MD6g
PKA6hjhodHRwOi8vY3JsLmQtdHJ1c3QubmV0L2NybC9kLXRydXN0X2JyX3Jvb3RfY2FfMV8y
MDIwLmNybDB5oHegdYZzbGRhcDovL2RpcmVjdG9yeS5kLXRydXN0Lm5ldC9DTj1ELVRSVVNU
JTIwQlIlMjBSb290JTIwQ0ElMjAxJTIwMjAyMCxPPUQtVHJ1c3QlMjBHbWJILEM9REU/Y2Vy
dGlmaWNhdGVyZXZvY2F0aW9ubGlzdDAKBggqhkjOPQQDAwNpADBmAjEAlJAtE/rhY/hhY+it
hXhUkZy4kzg+GkHaQBZTQgjKL47xPoFWwKrY7RjEsK70PvomAjEA8yjixtsrmfu3Ubgko6SU
eho/5jbiA1czijDLgsfWFBHVdWNbFJWcHwHP2NVypw87
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIC2zCCAmCgAwIBAgIQXwJB13qHfEwDo6yWjfv/0DAKBggqhkjOPQQDAzBIMQswCQYDVQQG
EwJERTEVMBMGA1UEChMMRC1UcnVzdCBHbWJIMSIwIAYDVQQDExlELVRSVVNUIEVWIFJvb3Qg
Q0EgMSAyMDIwMB4XDTIwMDIxMTEwMDAwMFoXDTM1MDIxMTA5NTk1OVowSDELMAkGA1UEBhMC
REUxFTATBgNVBAoTDEQtVHJ1c3QgR21iSDEiMCAGA1UEAxMZRC1UUlVTVCBFViBSb290IENB
IDEgMjAyMDB2MBAGByqGSM49AgEGBSuBBAAiA2IABPEL3YZDIBnfl4XoIkqbz52Yv7QFJsnL
46bSj8WeeHsxiamJrSc8ZRCC/N/DnU7wMyPE0jL1HLDfMxddxfCxivnvubcUyilKwg+pf3Vl
SSowZ/Rk99Yad9rDwpdhQntJraOCAQ0wggEJMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
FH8QARY3OqQo5FD4pPfsazK2/umLMA4GA1UdDwEB/wQEAwIBBjCBxgYDVR0fBIG+MIG7MD6g
PKA6hjhodHRwOi8vY3JsLmQtdHJ1c3QubmV0L2NybC9kLXRydXN0X2V2X3Jvb3RfY2FfMV8y
MDIwLmNybDB5oHegdYZzbGRhcDovL2RpcmVjdG9yeS5kLXRydXN0Lm5ldC9DTj1ELVRSVVNU
JTIwRVYlMjBSb290JTIwQ0ElMjAxJTIwMjAyMCxPPUQtVHJ1c3QlMjBHbWJILEM9REU/Y2Vy
dGlmaWNhdGVyZXZvY2F0aW9ubGlzdDAKBggqhkjOPQQDAwNpADBmAjEAyjzGKnXCXnViOTYA
YFqLwZOZzNnbQTs7h5kXO9XMT8oi96CAy/m0sRtW9XLS/BnRAjEAkfcwkz8QRitxpNA7RJvA
KQIFskF3UfN5Wp6OFKBOQtJbgfM0agPnIjhQW+0ZT0MW
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICGTCCAZ+gAwIBAgIQCeCTZaz32ci5PhwLBCou8zAKBggqhkjOPQQDAzBOMQswCQYDVQQG
EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xJjAkBgNVBAMTHURpZ2lDZXJ0IFRMUyBF
Q0MgUDM4NCBSb290IEc1MB4XDTIxMDExNTAwMDAwMFoXDTQ2MDExNDIzNTk1OVowTjELMAkG
A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSYwJAYDVQQDEx1EaWdpQ2VydCBU
TFMgRUNDIFAzODQgUm9vdCBHNTB2MBAGByqGSM49AgEGBSuBBAAiA2IABMFEoc8Rl1Ca3iOC
NQfN0MsYndLxf3c1TzvdlHJS7cI7+Oz6e2tYIOyZrsn8aLN1udsJ7MgT9U7GCh1mMEy7H0cK
PGEQQil8pQgO4CLp0zVozptjn4S1mU1YoI71VOeVyaNCMEAwHQYDVR0OBBYEFMFRRVBZqz7n
LFr6ICISB4CIfBFqMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49
BAMDA2gAMGUCMQCJao1H5+z8blUD2WdsJk6Dxv3J+ysTvLd6jLRl0mlpYxNjOyZQLgGheQaR
nUi/wr4CMEfDFXuxoJGZSZOoPHzoRgaLLPIxAJSdYsiJvRmEFOml+wG4DXZDjC5Ty3zfDBeW
UA==
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIFZjCCA06gAwIBAgIQCPm0eKj6ftpqMzeJ3nzPijANBgkqhkiG9w0BAQwFADBNMQswCQYD
VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xJTAjBgNVBAMTHERpZ2lDZXJ0IFRM
UyBSU0E0MDk2IFJvb3QgRzUwHhcNMjEwMTE1MDAwMDAwWhcNNDYwMTE0MjM1OTU5WjBNMQsw
CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xJTAjBgNVBAMTHERpZ2lDZXJ0
IFRMUyBSU0E0MDk2IFJvb3QgRzUwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCz
0PTJeRGd/fxmgefM1eS87IE+ajWOLrfn3q/5B03PMJ3qCQuZvWxX2hhKuHisOjmopkisLnLl
vevxGs3npAOpPxG02C+JFvuUAT27L/gTBaF4HI4o4EXgg/RZG5Wzrn4DReW+wkL+7vI8toUT
mDKdFqgpwgscONyfMXdcvyej/Cestyu9dJsXLfKB2l2w4SMXPohKEiPQ6s+d3gMXsUJKoBZM
pG2T6T867jp8nVid9E6P/DsjyG244gXazOvswzH016cpVIDPRFtMbzCe88zdH5RDnU1/cHAN
1DrRN/BsnZvAFJNY781BOHW8EwOVfH/jXOnVDdXifBBiqmvwPXbzP6PosMH976pXTayGpxi0
KcEsDr9kvimM2AItzVwv8n/vFfQMFawKsPHTDU9qTXeXAaDxZre3zu/O7Oyldcqs4+Fj97ih
BMi8ez9dLRYiVu1ISf6nL3kwJZu6ay0/nTvEF+cdLvvyz6b84xQslpghjLSR6Rlgg/IwKwZz
UNWYOwbpx4oMYIwo+FKbbuH2TbsGJJvXKyY//SovcfXWJL5/MZ4PbeiPT02jP/816t9JXkGP
hvnxd3lLG7SjXi/7RgLQZhNeXoVPzthwiHvOAbWWl9fNff2C+MIkwcoBOU+NosEUQB+cZtUM
CUbW8tDRSHZWOkPLtgoRObqME2wGtZ7P6wIDAQABo0IwQDAdBgNVHQ4EFgQUUTMc7TZArxfT
Jc1paPKvTiM+s0EwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcN
AQEMBQADggIBAGCmr1tfV9qJ20tQqcQjNSH/0GEwhJG3PxDPJY7Jv0Y02cEhJhxwGXIeo8mH
/qlDZJY6yFMECrZBu8RHANmfGBg7sg7zNOok992vIGCukihfNudd5N7HPNtQOa27PShNlnx2
xlv0wdsUpasZYgcYQF+Xkdycx6u1UQ3maVNVzDl92sURVXLFO4uJ+DQtpBflF+aZfTCIITfN
MBc9uPK8qHWgQ9w+iUuQrm0D4ByjoJYJu32jtyoQREtGBzRj7TG5BO6jm5qu5jF49OokYTur
WGT/u4cnYiWB39yhL/btp/96j1EuMPikAdKFOV8BmZZvWltwGUb+hmA+rYAQCd05JS9Yf7vS
dPD3Rh9GOUrYU9DzLjtxpdRv/PNn5AeP3SYZ4Y1b+qOTEZvpyDrDVWiakuFSdjjo4bq9+0/V
77PnSIMx8IIh47a+p6tv75/fTM8BuGJqIz3nCU2AG3swpMPdB380vqQmsvZB6Akd4yCYqjdP
//fx4ilwMUc/dNAUFvohigLVigmUdy7yWSiLfFCSCmZ4OIN1xLVaqBHG5cGdZlXPU8Sv13WF
qUITVuwhd4GTWgzqltlJyqEI8pc7bZsEGCREjnwB8twl2F6GmrE52/WRMmrRpnCKovfepEWF
JqgejF0pW8hL2JpqA15w8oVPbEtoL8pU9ozaMv7Da4M/OMZ+
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFRzCCAy+gAwIBAgIRAI4P+UuQcWhlM1T01EQ5t+AwDQYJKoZIhvcNAQELBQAwPTELMAkG
A1UEBhMCVVMxEjAQBgNVBAoTCUNlcnRhaW5seTEaMBgGA1UEAxMRQ2VydGFpbmx5IFJvb3Qg
UjEwHhcNMjEwNDAxMDAwMDAwWhcNNDYwNDAxMDAwMDAwWjA9MQswCQYDVQQGEwJVUzESMBAG
A1UEChMJQ2VydGFpbmx5MRowGAYDVQQDExFDZXJ0YWlubHkgUm9vdCBSMTCCAiIwDQYJKoZI
hvcNAQEBBQADggIPADCCAgoCggIBANA21B/q3avk0bbm+yLA3RMNansiExyXPGhjZjKcA7WN
pIGD2ngwEc/csiu+kr+O5MQTvqRoTNoCaBZ0vrLdBORrKt03H2As2/X3oXyVtwxwhi7xOu9S
98zTm/mLvg7fMbedaFySpvXl8wo0tf97ouSHocavFwDvA5HtqRxOcT3Si2yJ9HiG5mpJoM61
0rCrm/b01C7jcvk2xusVtyWMOvwlDbMicyF0yEqWYZL1LwsYpfSt4u5BvQF5+paMjRcCMLT5
r3gajLQ2EBAHBXDQ9DGQilHFhiZ5shGIXsXwClTNSaa/ApzSRKft43jvRl5tcdF5cBxGX1Hp
yTfcX35pe0HfNEXgO4T0oYoKNp43zGJS4YkNKPl6I7ENPT2a/Z2B7yyQwHtETrtJ4A5KVpK8
y7XdeReJkd5hiXSSqOMyhb5OhaRLWcsrxXiOcVTQAjeZjOVJ6uBUcqQRBi8LjMFbvrWhsFNu
nLhgkR9Za/kt9JQKl7XsxXYDVBtlUrpMklZRNaBA2CnbrlJ2Oy0wQJuK0EJWtLeIAaSHO1OW
zaMWj/Nmqhexx2DgwUMFDO6bW2BvBlyHWyf5QBGenDPBt+U1VwV/J84XIIwc/PH72jEpSe31
C4SnT8H2TsIonPru4K8H+zMReiFPCyEQtkA6qyI6BJyLm4SGcprSp6XEtHWRqSsjAgMBAAGj
QjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTgqj8ljZ9E
XME66C6ud0yEPmcM9DANBgkqhkiG9w0BAQsFAAOCAgEAuVevuBLaV4OPaAszHQNTVfSVcOQr
PbA56/qJYv331hgELyE03fFo8NWWWt7CgKPBjcZq91l3rhVkz1t5BXdm6ozTaw3d8VkswTOl
MIAVRQdFGjEitpIAq5lNOo93r6kiyi9jyhXWx8bwPWz8HA2YEGGeEaIi1wrykXprOQ4vMMM2
SZ/g6Q8CRFA3lFV96p/2O7qUpUzpvD5RtOjKkjZUbVwlKNrdrRT90+7iIgXr0PK3aBLXWopB
GsaSpVo7Y0VPv+E6dyIvXL9G+VoDhRNCX8reU9ditaY1BMJH/5n9hN9czulegChB8n3nHpDY
T3Y+gjwN/KUD+nsa2UUeYNrEjvn8K8l7lcUq/6qJ34IxD3L/DCfXCh5WAFAeDJDBlrXYFIW7
pw0WwfgHJBu6haEaBQmAupVjyTrsJZ9/nbqkRxWbRHDxakvWOF5D8xh+UG7pWijmZeZ3Gzr9
Hb4DJqPb1OG7fpYnKx3upPvaJVQTA945xsMfTZDsjxtK0hzthZU4UHlG1sGQUDGpXJpuHfUz
VounmdLyyCwzk5Iwx06MZTMQZBf9JBeW0Y3COmor6xOLRPIh80oat3df1+2IpHLlOR+Vnb5n
wXARPbv0+Em34yaXOp/SX3z7wJl8OSngex2/DaeP0ik0biQVy96QXr8axGbqwua6OV+KmalB
WQewLK8=
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIB9zCCAX2gAwIBAgIQBiUzsUcDMydc+Y2aub/M+DAKBggqhkjOPQQDAzA9MQswCQYDVQQG
EwJVUzESMBAGA1UEChMJQ2VydGFpbmx5MRowGAYDVQQDExFDZXJ0YWlubHkgUm9vdCBFMTAe
Fw0yMTA0MDEwMDAwMDBaFw00NjA0MDEwMDAwMDBaMD0xCzAJBgNVBAYTAlVTMRIwEAYDVQQK
EwlDZXJ0YWlubHkxGjAYBgNVBAMTEUNlcnRhaW5seSBSb290IEUxMHYwEAYHKoZIzj0CAQYF
K4EEACIDYgAE3m/4fxzf7flHh4axpMCK+IKXgOqPyEpeKn2IaKcBYhSRJHpcnqMXfYqGITQY
UBsQ3tA3SybHGWCA6TS9YBk2QNYphwk8kXr2vBMj3VlOBF7PyAIcGFPBMdjaIOlEjeR2o0Iw
QDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU8ygYy2R17ikq
6+2uI1g4hevIIgcwCgYIKoZIzj0EAwMDaAAwZQIxALGOWiDDshliTd6wT99u0nCK8Z9+aozm
ut6Dacpps6kFtZaSF4fC0urQe87YQVt8rgIwRt7qy12a7DLCZRawTDBcMPPaTnOGBtjOiQRI
Nzf43TNRnXCve1XYAS59BWQOhriR
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFfzCCA2egAwIBAgIJAOF8N0D9G/5nMA0GCSqGSIb3DQEBDAUAMF0xCzAJBgNVBAYTAkpQ
MSUwIwYDVQQKExxTRUNPTSBUcnVzdCBTeXN0ZW1zIENPLixMVEQuMScwJQYDVQQDEx5TZWN1
cml0eSBDb21tdW5pY2F0aW9uIFJvb3RDQTMwHhcNMTYwNjE2MDYxNzE2WhcNMzgwMTE4MDYx
NzE2WjBdMQswCQYDVQQGEwJKUDElMCMGA1UEChMcU0VDT00gVHJ1c3QgU3lzdGVtcyBDTy4s
TFRELjEnMCUGA1UEAxMeU2VjdXJpdHkgQ29tbXVuaWNhdGlvbiBSb290Q0EzMIICIjANBgkq
hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA48lySfcw3gl8qUCBWNO0Ot26YQ+TUG5pPDXC7ltz
kBtnTCHsXzW7OT4rCmDvu20rhvtxosis5FaU+cmvsXLUIKx00rgVrVH+hXShuRD+BYD5UpOz
QD11EKzAlrenfna84xtSGc4RHwsENPXY9Wk8d/Nk9A2qhd7gCVAEF5aEt8iKvE1y/By7z/MG
TfmfZPd+pmaGNXHIEYBMwXFAWB6+oHP2/D5Q4eAvJj1+XCO1eXDe+uDRpdYMQXF79+qMHIjH
7Iv10S9VlkZ8WjtYO/u62C21Jdp6Ts9EriGmnpjKIG58u4iFW/vAEGK78vknR+/RiTlDxN/e
4UG/VHMgly1s2vPUB6PmudhvrvyMGS7TZ2crldtYXLVqAvO4g160a75BflcJdURQVc1aEWEh
CmHCqYj9E7wtiS/NYeCVvsq1e+F7NGcLH7YMx3weGVPKp7FKFSBWFHA9K4IsD50VHUeAR/94
mQ4xr28+j+2GaR57GIgUssL8gjMunEst+3A7caoreyYn8xrC3PsXuKHqy6C0rtOUfnrQq8Ps
OC0RLoi/1D+tEjtCrI8Cbn3M0V9hvqG8OmpI6iZVIhZdXw3/JzOfGAN0iltSIEdrRU0id4xV
J/CvHozJgyJUt5rQT9nO/NkuHJYosQLTA70lUhw0Zk8jq/R3gpYd0VcwCBEF/VfR2ccCAwEA
AaNCMEAwHQYDVR0OBBYEFGQUfPxYchamCik0FW8qy7z8r6irMA4GA1UdDwEB/wQEAwIBBjAP
BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBDAUAA4ICAQDcAiMI4u8hOscNtybSYpOnpSNy
ByCCYN8Y11StaSWSntkUz5m5UoHPrmyKO1o5yGwBQ8IibQLwYs1OY0PAFNr0Y/Dq9HHuTofj
can0yVflLl8cebsjqodEV+m9NU1Bu0soo5iyG9kLFwfl9+qd9XbXv8S2gVj/yP9kaWJ5rW4O
H3/uHWnlt3Jxs/6lATWUVCvAUm2PVcTJ0rjLyjQIUYWg9by0F1jqClx6vWPGOi//lkkZhOpn
2ASxYfQAW0q3nHE3GYV5v4GwxxMOdnE+OoAGrgYWp421wsTL/0ClXI2lyTrtcoHKXJg80jQD
dwj98ClZXSEIx2C/pHF7uNkegr4Jr2VvKKu/S7XuPghHJ6APbw+LP6yVGPO5DtxnVW5inkYO
0QR4ynKudtml+LLfiAlhi+8kTtFZP1rUPcmTPCtk9YENFpb3ksP+MW/oKjJ0DvRMmEoYDjBU
1cXrvMUVnuiZIesnKwkK2/HmcBhWuwzkvvnoEKQTkrgc4NtnHVMDpCKn3F2SEDzq//wbEBrD
2NCcnWXL0CsnMQMeNuE9dnUM/0Umud1RvCPHX9jYhxBAEg09ODfnRDwYwFMJZI//1ZqmfHAu
c1Uh6N//g7kdPjIe1qZ9LPFm6Vwdp6POXiUyK+OVrCoHzrQoeIY8LaadTdJ0MN1kURXbg4NR
16/9M51NZg==
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIICODCCAb6gAwIBAgIJANZdm7N4gS7rMAoGCCqGSM49BAMDMGExCzAJBgNVBAYTAkpQMSUw
IwYDVQQKExxTRUNPTSBUcnVzdCBTeXN0ZW1zIENPLixMVEQuMSswKQYDVQQDEyJTZWN1cml0
eSBDb21tdW5pY2F0aW9uIEVDQyBSb290Q0ExMB4XDTE2MDYxNjA1MTUyOFoXDTM4MDExODA1
MTUyOFowYTELMAkGA1UEBhMCSlAxJTAjBgNVBAoTHFNFQ09NIFRydXN0IFN5c3RlbXMgQ08u
LExURC4xKzApBgNVBAMTIlNlY3VyaXR5IENvbW11bmljYXRpb24gRUNDIFJvb3RDQTEwdjAQ
BgcqhkjOPQIBBgUrgQQAIgNiAASkpW9gAwPDvTH00xecK4R1rOX9PVdu12O/5gSJko6BnOPp
R27KkBLIE+CnnfdldB9sELLo5OnvbYUymUSxXv3MdhDYW72ixvnWQuRXdtyQwjWpS4g8Ekdt
XP9JTxpKULGjQjBAMB0GA1UdDgQWBBSGHOf+LaVKiwj+KBH6vqNm+GBZLzAOBgNVHQ8BAf8E
BAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAwNoADBlAjAVXUI9/Lbu9zuxNuie
9sRGKEkz0FhDKmMpzE2xtHqiuQ04pV1IKv3LsnNdo4gIxwwCMQDAqy0Obe0YottT6SXbVQjg
UMzfRGEWgqtJsLKB7HOHeLRMsmIbEvoWTSVLY70eN9k=
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIFdDCCA1ygAwIBAgIQVW9l47TZkGobCdFsPsBsIDANBgkqhkiG9w0BAQsFADBUMQswCQYD
VQQGEwJDTjEmMCQGA1UECgwdQkVJSklORyBDRVJUSUZJQ0FURSBBVVRIT1JJVFkxHTAbBgNV
BAMMFEJKQ0EgR2xvYmFsIFJvb3QgQ0ExMB4XDTE5MTIxOTAzMTYxN1oXDTQ0MTIxMjAzMTYx
N1owVDELMAkGA1UEBhMCQ04xJjAkBgNVBAoMHUJFSUpJTkcgQ0VSVElGSUNBVEUgQVVUSE9S
SVRZMR0wGwYDVQQDDBRCSkNBIEdsb2JhbCBSb290IENBMTCCAiIwDQYJKoZIhvcNAQEBBQAD
ggIPADCCAgoCggIBAPFmCL3ZxRVhy4QEQaVpN3cdwbB7+sN3SJATcmTRuHyQNZ0YeYjjlwE8
R4HyDqKYDZ4/N+AZspDyRhySsTphzvq3Rp4Dhtczbu33RYx2N95ulpH3134rhxfVizXuhJFy
V9xgw8O558dnJCNPYwpj9mZ9S1WnP3hkSWkSl+BMDdMJoDIwOvqfwPKcxRIqLhy1BDPapDgR
at7GGPZHOiJBhyL8xIkoVNiMpTAK+BcWyqw3/XmnkRd4OJmtWO2y3syJfQOcs4ll5+M7sSKG
jwZteAf9kRJ/sGsciQ35uMt0WwfCyPQ10WRjeulumijWML3mG90Vr4TqnMfK9Q7q8l0ph49p
czm+LiRvRSGsxdRpJQaDrXpIhRMsDQa4bHlW/KNnMoH1V6XKV0Jp6VwkYe/iMBhORJhVb3rC
k9gZtt58R4oRTklH2yiUAguUSiz5EtBP6DF+bHq/pj+bOT0CFqMYs2esWz8sgytnOYFcuX6U
1WTdno9uruh8W7TXakdI136z1C2OVnZOz2nxbkRs1CTqjSShGL+9V/6pmTW12xB3uD1IutbB
5/EjPtffhZ0nPNRAvQoMvfXnjSXWgXSHRtQpdaJCbPdzied9v3pKH9MiyRVVz99vfFXQpIsH
ETdfg6YmV6YBW37+WGgHqel62bno/1Afq8K0wM7o6v0PvY1NuLxxAgMBAAGjQjBAMB0GA1Ud
DgQWBBTF7+3M2I0hxkjk49cULqcWk+WYATAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQE
AwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAUoKsITQfI/Ki2Pm4rzc2IInRNwPWaZ+4YRC6ojGY
WUfo0Q0lHhVBDOAqVdVXUsv45Mdpox1NcQJeXyFFYEhcCY5JEMEE3KliawLwQ8hOnThJdMky
cFRtwUf8jrQ2ntScvd0g1lPJGKm1Vrl2i5VnZu69mP6u775u+2D2/VnGKhs/I0qUJDAnyIm8
60Qkmss9vk/Ves6OF8tiwdneHg56/0OGNFK8YT88X7vZdrRTvJez/opMEi4r89fO4aL/3Xtw
+zuhTaRjAv04l5U/BXCga99igUOLtFkNSoxUnMW7gZ/NfaXvCyUeOiDbHPwfmGcCCtRzRBPb
UYQaVQNW4AB+dAb/OMRyHdOoP2gxXdMJxy6MW2Pg6Nwe0uxhHvLe5e/2mXZgLR6UcnHGCyoy
x5JO1UbXHfmpGQrI+pXObSOYqgs4rZpWDW+N8TEAiMEXnM0ZNjX+VVOg4DwzX5Ze4jLp3zO7
Bkqp2IRzznfSxqxx4VyjHQy7Ct9f4qNx2No3WqB4K/TUfet27fJhcKVlmtOJNBir+3I+17Q9
eVzYH6Eze9mCUAyTF6ps3MKCuwJXNq+YJyo5UOGwifUll35HaBC07HPKs5fRJNz2YqAo07Wj
uGS3iGJCz51TzZm+ZGiPTx4SSPfSKcOYKMryMguTjClPPGAyzQWWYezyr/6zcCwupvI=
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIICJTCCAaugAwIBAgIQLBcIfWQqwP6FGFkGz7RK6zAKBggqhkjOPQQDAzBUMQswCQYDVQQG
EwJDTjEmMCQGA1UECgwdQkVJSklORyBDRVJUSUZJQ0FURSBBVVRIT1JJVFkxHTAbBgNVBAMM
FEJKQ0EgR2xvYmFsIFJvb3QgQ0EyMB4XDTE5MTIxOTAzMTgyMVoXDTQ0MTIxMjAzMTgyMVow
VDELMAkGA1UEBhMCQ04xJjAkBgNVBAoMHUJFSUpJTkcgQ0VSVElGSUNBVEUgQVVUSE9SSVRZ
MR0wGwYDVQQDDBRCSkNBIEdsb2JhbCBSb290IENBMjB2MBAGByqGSM49AgEGBSuBBAAiA2IA
BJ3LgJGNU2e1uVCxA/jlSR9BIgmwUVJY1is0j8USRhTFiy8shP8sbqjV8QnjAyEUxEM9fMEs
xEtqSs3ph+B99iK++kpRuDCK/eHeGBIK9ke35xe/J4rUQUyWPGCWwf0VHKNCMEAwHQYDVR0O
BBYEFNJKsVF/BvDRgh9Obl+rg/xI1LCRMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQD
AgEGMAoGCCqGSM49BAMDA2gAMGUCMBq8W9f+qdJUDkpd0m2xQNz0Q9XSSpkZElaA94M04TVO
SG0ED1cxMDAtsaqdAzjbBgIxAMvMh1PLet8gUXOQwKhbYdDFUDn9hf7B43j4ptZLvZuHjw/l
1lOWqzzIQNph91Oj9w==
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIICOjCCAcGgAwIBAgIQQvLM2htpN0RfFf51KBC49DAKBggqhkjOPQQDAzBfMQswCQYDVQQG
EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYwNAYDVQQDEy1TZWN0aWdvIFB1Ymxp
YyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBFNDYwHhcNMjEwMzIyMDAwMDAwWhcNNDYw
MzIxMjM1OTU5WjBfMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYw
NAYDVQQDEy1TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBFNDYw
djAQBgcqhkjOPQIBBgUrgQQAIgNiAAR2+pmpbiDt+dd34wc7qNs9Xzjoq1WmVk/WSOrsfy2q
w7LFeeyZYX8QeccCWvkEN/U0NSt3zn8gj1KjAIns1aeibVvjS5KToID1AZTc8GgHHs3u/iVS
tSBDHBv+6xnOQ6OjQjBAMB0GA1UdDgQWBBTRItpMWfFLXyY4qp3W7usNw/upYTAOBgNVHQ8B
Af8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAwNnADBkAjAn7qRaqCG76UeX
lImldCBteU/IvZNeWBj7LRoAasm4PdCkT0RHlAFWovgzJQxC36oCMB3q4S6ILuH5px0CMk7y
n2xVdOOurvulGu7t0vzCAxHrRVxgED1cf5kDW21USAGKcw==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFijCCA3KgAwIBAgIQdY39i658BwD6qSWn4cetFDANBgkqhkiG9w0BAQwFADBfMQswCQYD
VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTYwNAYDVQQDEy1TZWN0aWdvIFB1
YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcN
NDYwMzIxMjM1OTU5WjBfMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
MTYwNAYDVQQDEy1TZWN0aWdvIFB1YmxpYyBTZXJ2ZXIgQXV0aGVudGljYXRpb24gUm9vdCBS
NDYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCTvtU2UnXYASOgHEdCSe5jtrch
/cSV1UgrJnwUUxDaef0rty2k1Cz66jLdScK5vQ9IPXtamFSvnl0xdE8H/FAh3aTPaE8bEmNt
JZlMKpnzSDBh+oF8HqcIStw+KxwfGExxqjWMrfhu6DtK2eWUAtaJhBOqbchPM8xQljeSM9xf
iOefVNlI8JhD1mb9nxc4Q8UBUQvX4yMPFF1bFOdLvt30yNoDN9HWOaEhUTCDsG3XME6WW5Hw
cCSrv0WBZEMNvSE6Lzzpng3LILVCJ8zab5vuZDCQOc2TZYEhMbUjUDM3IuM47fgxMMxF/mL5
0V0yeUKH32rMVhlATc6qu/m1dkmU8Sf4kaWD5QazYw6A3OASVYCmO2a0OYctyPDQ0RTp5A1N
DvZdV3LFOxxHVp3i1fuBYYzMTYCQNFu31xR13NgESJ/AwSiItOkcyqex8Va3e0lMWeUgFaiE
Ain6OJRpmkkGj80feRQXEgyDet4fsZfu+Zd4KKTIRJLpfSYFplhym3kT2BFfrsU4YjRosoYw
jviQYZ4ybPUHNs2iTG7sijbt8uaZFURww3y8nDnAtOFr94MlI1fZEoDlSfB1D++N6xybVCi0
ITz8fAr/73trdf+LHaAZBav6+CuBQug4urv7qv094PPK306Xlynt8xhW6aWWrL3DkJiy4Pmi
1KZHQ3xtzwIDAQABo0IwQDAdBgNVHQ4EFgQUVnNYZJX5khqwEioEYnmhQBWIIUkwDgYDVR0P
AQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEMBQADggIBAC9cmTz8Bl6M
lC5w6tIyMY208FHVvArzZJ8HXtXBc2hkeqK5Duj5XYUtqDdFqij0lgVQYKlJfp/imTYpE0RH
ap1VIDzYm/EDMrraQKFz6oOht0SmDpkBm+S8f74TlH7Kph52gDY9hAaLMyZlbcp+nv4fjFg4
exqDsQ+8FxG75gbMY/qB8oFM2gsQa6H61SilzwZAFv97fRheORKkU55+MkIQpiGRqRxOF3yE
vJ+M0ejf5lG5Nkc/kLnHvALcWxxPDkjBJYOcCj+esQMzEhonrPcibCTRAUH4WAP+JWgiH5pa
PHxsnnVI84HxZmduTILA7rpXDhjvLpr3Etiga+kFpaHpaPi8TD8SHkXoUsCjvxInebnMMTzD
9joiFgOgyY9mpFuiTdaBJQbpdqQACj7LzTWb4OE4y2BThihCQRxEV+ioratF4yUQvNs+ZUH7
G6aXD+u5dHn5HrwdVw1Hr8Mvn4dGp+smWg9WY7ViYG4A++MnESLn/pmPNPW56MORcr3Ywx65
LvKRRFHQV80MNNVIIb/bE/FmJUNS0nAiNs2fxBx1IK1jcmMGDw4nztJqDby1ORrp0XZ60Vzk
50lJLVU3aPAaOpg+VBeHVOmmJ1CJeyAvP/+/oYtKR5j/K3tJPsMpRmAYQqszKbrAKbkTidOI
ijlBO8n9pu0f9GBj39ItVQGL
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFiTCCA3GgAwIBAgIQb77arXO9CEDii02+1PdbkTANBgkqhkiG9w0BAQsFADBOMQswCQYD
VQQGEwJVUzEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMSUwIwYDVQQDDBxTU0wuY29tIFRM
UyBSU0EgUm9vdCBDQSAyMDIyMB4XDTIyMDgyNTE2MzQyMloXDTQ2MDgxOTE2MzQyMVowTjEL
MAkGA1UEBhMCVVMxGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjElMCMGA1UEAwwcU1NMLmNv
bSBUTFMgUlNBIFJvb3QgQ0EgMjAyMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ANCkCXJPQIgSYT41I57u9nTPL3tYPc48DRAokC+X94xI2KDYJbFMsBFMF3NQ0CJKY7uB0ylu
1bUJPiYYf7ISf5OYt6/wNr/y7hienDtSxUcZXXTzZGbVXcdotL8bHAajvI9AI7YexoS9UcQb
OcGV0insS657Lb85/bRi3pZ7QcacoOAGcvvwB5cJOYF0r/c0WRFXCsJbwST0MXMwgsadugL3
PnxEX4MN8/HdIGkWCVDi1FW24IBydm5MR7d1VVm0U3TZlMZBrViKMWYPHqIbKUBOL9975hYs
Lfy/7PO0+r4Y9ptJ1O4Fbtk085zx7AGL0SDGD6C1vBdOSHtRwvzpXGk3R2azaPgVKPC506QV
zFpPulJwoxJF3ca6TvvC0PeoUidtbnm1jPx7jMEWTO6Af77wdr5BUxIzrlo4QqvXDz5BjXYH
MtWrifZOZ9mxQnUjbvPNQrL8VfVThxc7wDNY8VLS+YCk8OjwO4s4zKTGkH8PnP2L0aPP2oOn
aclQNtVcBdIKQXTbYxE3waWglksejBYSd66UNHsef8JmAOSqg+qKkK3ONkRN0VHpvB/zagX9
wHQfJRlAUW7qglFA35u5CCoGAtUjHBPW6dvbxrB6y3snm/vg1UYk7RBLY0ulBY+6uB0rpvqR
4pJSvezrZ5dtmi2fgTIFZzL7SAg/2SW4BCUvAgMBAAGjYzBhMA8GA1UdEwEB/wQFMAMBAf8w
HwYDVR0jBBgwFoAU+y437uOEeicuzRk1sTN8/9REQrkwHQYDVR0OBBYEFPsuN+7jhHonLs0Z
NbEzfP/UREK5MA4GA1UdDwEB/wQEAwIBhjANBgkqhkiG9w0BAQsFAAOCAgEAjYlthEUY8U+z
oO9opMAdrDC8Z2awms22qyIZZtM7QbUQnRC6cm4pJCAcAZli05bg4vsMQtfhWsSWTVTNj8pD
U/0quOr4ZcoBwq1gaAafORpR2eCNJvkLTqVTJXojpBzOCBvfR4iyrT7gJ4eLSYwfqUdYe5by
iB0YrrPRpgqU+tvT5TgKa3kSM/tKWTcWQA673vWJDPFs0/dRa1419dvAJuoSc06pkZCmF8Ns
LzjUo3KUQyxi4U5cMj29TH0ZR6LDSeeWP4+a0zvkEdiLA9z2tmBVGKaBUfPhqBVq6+AL8BQx
1rmMRTqoENjwuSfr98t67wVylrXEj5ZzxOhWc5y8aVFjvO9nHEMaX3cZHxj4HCUp+UmZKbaS
PaKDN7EgkaibMOlqbLQjk2UEqxHzDh1TJElTHaE/nUiSEeJ9DU/1172iWD54nR4fK/4huxoT
trEoZP2wAgDHbICivRZQIA9ygV/MlP+7mea6kMvq+cYMwq7FGc4zoWtcu358NFcXrfA/rs3q
r5nsLFR+jM4uElZI7xc7P0peYNLcdDa8pUNjyw9bowJWCZ4kLOGGgYz+qxcs+sjiMho6/4UI
yYOf8kpIEFR3N+2ivEC+5BB09+Rbu7nzifmPQdjH5FCQNYA+HLhNkNPU98OwoX6EyneSMSy4
kLGCenROmxMmtNVQZlR4rmA=
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICOjCCAcCgAwIBAgIQFAP1q/s3ixdAW+JDsqXRxDAKBggqhkjOPQQDAzBOMQswCQYDVQQG
EwJVUzEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMSUwIwYDVQQDDBxTU0wuY29tIFRMUyBF
Q0MgUm9vdCBDQSAyMDIyMB4XDTIyMDgyNTE2MzM0OFoXDTQ2MDgxOTE2MzM0N1owTjELMAkG
A1UEBhMCVVMxGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjElMCMGA1UEAwwcU1NMLmNvbSBU
TFMgRUNDIFJvb3QgQ0EgMjAyMjB2MBAGByqGSM49AgEGBSuBBAAiA2IABEUpNXP6wrgjzhR9
qLFNoFs27iosU8NgCTWyJGYmacCzldZdkkAZDsalE3D07xJRKF3nzL35PIXBz5SQySvOkkJY
WWf9lCcQZIxPBLFNSeR7T5v15wj4A4j3p8OSSxlUgaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAf
BgNVHSMEGDAWgBSJjy+j6CugFFR781a4Jl9nOAuc0DAdBgNVHQ4EFgQUiY8vo+groBRUe/NW
uCZfZzgLnNAwDgYDVR0PAQH/BAQDAgGGMAoGCCqGSM49BAMDA2gAMGUCMFXjIlbp15IkWE8e
lDIPDAI2wv2sdDJO4fscgIijzPvX6yv/N33w7deedWo1dlJF4AIxAMeNb0Igj762TVntd00p
xCAgRWSGOlDGxK0tk/UYfXLtqc/ErFc2KAhl3zx5Zn6g6g==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICFTCCAZugAwIBAgIQPZg7pmY9kGP3fiZXOATvADAKBggqhkjOPQQDAzBMMS4wLAYDVQQD
DCVBdG9zIFRydXN0ZWRSb290IFJvb3QgQ0EgRUNDIFRMUyAyMDIxMQ0wCwYDVQQKDARBdG9z
MQswCQYDVQQGEwJERTAeFw0yMTA0MjIwOTI2MjNaFw00MTA0MTcwOTI2MjJaMEwxLjAsBgNV
BAMMJUF0b3MgVHJ1c3RlZFJvb3QgUm9vdCBDQSBFQ0MgVExTIDIwMjExDTALBgNVBAoMBEF0
b3MxCzAJBgNVBAYTAkRFMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEloZYKDcKZ9Cg3iQZGeHk
BQcfl+3oZIK59sRxUM6KDP/XtXa7oWyTbIOiaG6l2b4siJVBzV3dscqDY4PMwL502eCdpO5K
TlbgmClBk1IQ1SQ4AjJn8ZQSb+/Xxd4u/RmAo0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1Ud
DgQWBBR2KCXWfeBmmnoJsmo7jjPXNtNPojAOBgNVHQ8BAf8EBAMCAYYwCgYIKoZIzj0EAwMD
aAAwZQIwW5kp85wxtolrbNa9d+F851F+uDrNozZffPc8dz7kUK2o59JZDCaOMDtuCCrCp1rI
AjEAmeMM56PDr9NJLkaCI2ZdyQAUEv049OGYa3cpetskz2VAv9LcjBHo9H1/IISpQuQo
-----END CERTIFICATE-----     -----BEGIN CERTIFICATE-----
MIIFZDCCA0ygAwIBAgIQU9XP5hmTC/srBRLYwiqipDANBgkqhkiG9w0BAQwFADBMMS4wLAYD
VQQDDCVBdG9zIFRydXN0ZWRSb290IFJvb3QgQ0EgUlNBIFRMUyAyMDIxMQ0wCwYDVQQKDARB
dG9zMQswCQYDVQQGEwJERTAeFw0yMTA0MjIwOTIxMTBaFw00MTA0MTcwOTIxMDlaMEwxLjAs
BgNVBAMMJUF0b3MgVHJ1c3RlZFJvb3QgUm9vdCBDQSBSU0EgVExTIDIwMjExDTALBgNVBAoM
BEF0b3MxCzAJBgNVBAYTAkRFMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtoAO
xHm9BYx9sKOdTSJNy/BBl01Z4NH+VoyX8te9j2y3I49f1cTYQcvyAh5x5en2XssIKl4w8i1m
x4QbZFc4nXUtVsYvYe+W/CBGvevUez8/fEc4BKkbqlLfEzfTFRVOvV98r61jx3ncCHvVoOX3
W3WsgFWZkmGbzSoXfduP9LVq6hdKZChmFSlsAvFr1bqjM9xaZ6cF4r9lthawEO3NUDPJcFDs
GY6wx/J0W2tExn2WuZgIWWbeKQGb9Cpt0xU6kGpn8bRrZtkh68rZYnxGEFzedUlnnkL5/nWp
o63/dgpnQOPF943HhZpZnmKaau1Fh5hnstVKPNe0OwANwI8f4UDErmwh3El+fsqyjW22v5Mv
oVw+j8rtgI5Y4dtXz4U2OLJxpAmMkokIiEjxQGMYsluMWuPD0xeqqxmjLBvk1cbiZnrXghmm
OxYsL3GHX0WelXOTwkKBIROW1527k2gV+p2kHYzygeBYBr3JtuP2iV2J+axEoctr+hbxx1A9
JNr3w+SH1VbxT5Aw+kUJWdo0zuATHAR8ANSbhqRAvNncTFd+rrcztl524WWLZt+NyteYr842
mIycg5kDcPOvdO3GDjbnvezBc6eUWsuSZIKmAMFwoW4sKeFYV+xafJlrJaSQOoD0IJ2azsct
+bJLKZWD6TWNp0lIpw9MGZHQ9b8Q4HECAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNV
HQ4EFgQUdEmZ0f+0emhFdcN+tNzMzjkz2ggwDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEB
DAUAA4ICAQAjQ1MkYlxt/T7Cz1UAbMVWiLkO3TriJQ2VSpfKgInuKs1l+NsW4AmS4BjHeJi7
8+xCUvuppILXTdiK/ORO/auQxDh1MoSf/7OwKwIzNsAQkG8dnK/haZPso0UvFJ/1TCplQ3IM
98P4lYsU84UgYt1UU90s3BiVaU+DR3BAM1h3Egyi61IxHkzJqM7F78PRreBrAwA0JrRUITWX
AdxfG/F851X6LWh3e9NpzNMOa7pNdkTWwhWaJuywxfW70Xp0wmzNxbVe9kzmWy2B27O3Opee
7c9GslA9hGCZcbUztVdF5kJHdWoOsAgMrr3e97sPWD2PAzHoPYJQyi9eDF20l74gNAf0xBLh
7tew2VktafcxBPTy+av5EzH4AXcOPUIjJsyacmdRIXrMPIWo6iFqO9taPKU0nprALN+AnCng
33eU0aKAQv9qTFsR0PXNor6uzFFcw9VUewyu1rkGd4Di7wcaaMxZUa1+XGdrudviB0JbuAEF
WDlN5LuYo7Ey7Nmj1m+UI/87tyll5gfp77YZ6ufCOB0yiJA8EytuzO+rdwY0d4RPcuSBhPm5
dDTedk+SKlOxJTnbPP/lPqYO5Wue/9vsL3SD3460s6neFE3/MaNFcyT6lSnMEpcEoji2jbDw
N/zIIX8/syQbPYtuzE2wFg2WHYMfRsCbvUOZ58SWLs5fyQ==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFpTCCA42gAwIBAgIUZPYOZXdhaqs7tOqFhLuxibhxkw8wDQYJKoZIhvcNAQEMBQAwWjEL
MAkGA1UEBhMCQ04xJTAjBgNVBAoMHFRydXN0QXNpYSBUZWNobm9sb2dpZXMsIEluYy4xJDAi
BgNVBAMMG1RydXN0QXNpYSBHbG9iYWwgUm9vdCBDQSBHMzAeFw0yMTA1MjAwMjEwMTlaFw00
NjA1MTkwMjEwMTlaMFoxCzAJBgNVBAYTAkNOMSUwIwYDVQQKDBxUcnVzdEFzaWEgVGVjaG5v
bG9naWVzLCBJbmMuMSQwIgYDVQQDDBtUcnVzdEFzaWEgR2xvYmFsIFJvb3QgQ0EgRzMwggIi
MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDAMYJhkuSUGwoqZdC+BqmHO1ES6nBBruL7
dOoKjbmzTNyPtxNST1QY4SxzlZHFZjtqz6xjbYdT8PfxObegQ2OwxANdV6nnRM7EoYNl9lA+
sX4WuDqKAtCWHwDNBSHvBm3dIZwZQ0WhxeiAysKtQGIXBsaqvPPW5vxQfmZCHzyLpnl5hkA1
nyDvP+uLRx+PjsXUjrYsyUQE49RDdT/VP68czH5GX6zfZBCK70bwkPAPLfSIC7Epqq+FqklY
qL9joDiR5rPmd2jE+SoZhLsO4fWvieylL1AgdB4SQXMeJNnKziyhWTXAyB1GJ2Faj/lN03J5
Zh6fFZAhLf3ti1ZwA0pJPn9pMRJpxx5cynoTi+jm9WAPzJMshH/x/Gr8m0ed262IPfN2dTPX
S6TIi/n1Q1hPy8gDVI+lhXgEGvNz8teHHUGf59gXzhqcD0r83ERoVGjiQTz+LISGNzzNPy+i
2+f3VANfWdP3kXjHi3dqFuVJhZBFcnAvkV34PmVACxmZySYgWmjBNb9Pp1Hx2BErW+Canig7
CjoKH8GB5S7wprlppYiU5msTf9FkPz2ccEblooV7WIQn3MSAPmeamseaMQ4w7OYXQJXZRe0B
lqq/DPNL0WP3E1jAuPP6Z92bfW1K/zJMtSU7/xxnD4UiWQWRkUF3gdCFTIcQcf+eQxuulXUt
gQIDAQABo2MwYTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFEDk5PIj7zjKsK5Xf/Ih
MBY027ySMB0GA1UdDgQWBBRA5OTyI+84yrCuV3/yITAWNNu8kjAOBgNVHQ8BAf8EBAMCAQYw
DQYJKoZIhvcNAQEMBQADggIBACY7UeFNOPMyGLS0XuFlXsSUT9SnYaP4wM8zAQLpw6o1D/GU
E3d3NZ4tVlFEbuHGLige/9rsR82XRBf34EzC4Xx8MnpmyFq2XFNFV1pF1AWZLy4jVe5jaN/T
G3inEpQGAHUNcoTpLrxaatXeL1nHo+zSh2bbt1S1JKv0Q3jbSwTEb93mPmY+KfJLaHEih6D4
sTNjduMNhXJEIlU/HHzp/LgV6FL6qj6jITk1dImmasI5+njPtqzn59ZW/yOSLlALqbUHM/Q4
X6RJpstlcHboCoWASzY9M/eVVHUl2qzEc4Jl6VL1XP04lQJqaTDFHApXB64ipCz5xUG3uOyf
T0gA+QEEVcys+TIxxHWVBqB/0Y0n3bOppHKH/lmLmnp0Ft0WpWIp6zqW3IunaFnT63eROfjX
y9mPX1onAX1daBli2MjN9LdyR75bl87yraKZk62Uy5P2EgmVtqvXO9A/EcswFi55gORngS1d
7XB4tmBZrOFdRWOPyN9yaFvqHbgB8X7754qz41SgOAngPN5C8sLtLpvzHzW2NtjjgKGLzZlk
D8Kqq7HK9W+eQ42EVJmzbsASZthwEPEGNTNDqJwuuhQxzhB/HIbjj9LV+Hfsm6vxL2PZQl/g
Z4FkkfGXL/xuJvYz+NO1+MRiqzFRJQJ6+N1rZdVtTTDIZbpoFGWsJwt0ivKH
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIICVTCCAdygAwIBAgIUTyNkuI6XY57GU4HBdk7LKnQV1tcwCgYIKoZIzj0EAwMwWjELMAkG
A1UEBhMCQ04xJTAjBgNVBAoMHFRydXN0QXNpYSBUZWNobm9sb2dpZXMsIEluYy4xJDAiBgNV
BAMMG1RydXN0QXNpYSBHbG9iYWwgUm9vdCBDQSBHNDAeFw0yMTA1MjAwMjEwMjJaFw00NjA1
MTkwMjEwMjJaMFoxCzAJBgNVBAYTAkNOMSUwIwYDVQQKDBxUcnVzdEFzaWEgVGVjaG5vbG9n
aWVzLCBJbmMuMSQwIgYDVQQDDBtUcnVzdEFzaWEgR2xvYmFsIFJvb3QgQ0EgRzQwdjAQBgcq
hkjOPQIBBgUrgQQAIgNiAATxs8045CVD5d4ZCbuBeaIVXxVjAd7Cq92zphtnS4CDr5nLrBfb
K5bKfFJV4hrhPVbwLxYI+hW8m7tH5j/uqOFMjPXTNvk4XatwmkcN4oFBButJ+bAp3TPsUKV/
eSm4IJijYzBhMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUpbtKl86zK3+kMd6Xg1mD
pm9xy94wHQYDVR0OBBYEFKW7SpfOsyt/pDHel4NZg6ZvccveMA4GA1UdDwEB/wQEAwIBBjAK
BggqhkjOPQQDAwNnADBkAjBe8usGzEkxn0AAbbd+NvBNEU/zy4k6LHiRUKNbwMp1JvK/kF0L
goxgKJ/GcJpo5PECMFxYDlZ2z1jD1xCMuo6u47xkdUfFVZDj/bpV6wfEU6s3qe4hsiFbYI89
MvHVI5TWWA==
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIICHTCCAaOgAwIBAgIUQ3CCd89NXTTxyq4yLzf39H91oJ4wCgYIKoZIzj0EAwMwTjELMAkG
A1UEBhMCVVMxEjAQBgNVBAoMCUNvbW1TY29wZTErMCkGA1UEAwwiQ29tbVNjb3BlIFB1Ymxp
YyBUcnVzdCBFQ0MgUm9vdC0wMTAeFw0yMTA0MjgxNzM1NDNaFw00NjA0MjgxNzM1NDJaME4x
CzAJBgNVBAYTAlVTMRIwEAYDVQQKDAlDb21tU2NvcGUxKzApBgNVBAMMIkNvbW1TY29wZSBQ
dWJsaWMgVHJ1c3QgRUNDIFJvb3QtMDEwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAARLNumuV16o
cNfQj3Rid8NeeqrltqLxeP0CflfdkXmcbLlSiFS8LwS+uM32ENEp7LXQoMPwiXAZu1FlxUOc
w5tjnSCDPgYLpkJEhRGnSjot6dZoL0hOUysHP029uax3OVejQjBAMA8GA1UdEwEB/wQFMAMB
Af8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBSOB2LAUN3GGQYARnQE9/OufXVNMDAKBggq
hkjOPQQDAwNoADBlAjEAnDPfQeMjqEI2Jpc1XHvr20v4qotzVRVcrHgpD7oh2MSg2NED3W3R
OT3Ek2DS43KyAjB8xX6I01D1HiXo+k515liWpDVfG2XqYZpwI7UNo5uSUm9poIyNStDuiw7L
R47QjRE=
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIICHDCCAaOgAwIBAgIUKP2ZYEFHpgE6yhR7H+/5aAiDXX0wCgYIKoZIzj0EAwMwTjELMAkG
A1UEBhMCVVMxEjAQBgNVBAoMCUNvbW1TY29wZTErMCkGA1UEAwwiQ29tbVNjb3BlIFB1Ymxp
YyBUcnVzdCBFQ0MgUm9vdC0wMjAeFw0yMTA0MjgxNzQ0NTRaFw00NjA0MjgxNzQ0NTNaME4x
CzAJBgNVBAYTAlVTMRIwEAYDVQQKDAlDb21tU2NvcGUxKzApBgNVBAMMIkNvbW1TY29wZSBQ
dWJsaWMgVHJ1c3QgRUNDIFJvb3QtMDIwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAR4MIHoYx7l
63FRD/cHB8o5mXxO1Q/MMDALj2aTPs+9xYa9+bG3tD60B8jzljHz7aRP+KNOjSkVWLjVb3/u
bCK1sK9IRQq9qEmUv4RDsNuESgMjGWdqb8FuvAY5N9GIIvejQjBAMA8GA1UdEwEB/wQFMAMB
Af8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBTmGHX/72DehKT1RsfeSlXjMjZ59TAKBggq
hkjOPQQDAwNnADBkAjAmc0l6tqvmSfR9Uj/UQQSugEODZXW5hYA4O9Zv5JOGq4/nich/m35r
ChJVYaoR4HkCMHfoMXGsPHED1oQmHhS48zs73u1Z/GtMMH9ZzkXpc2AVmkzw5l4lIhVtwodZ
0LKOag==
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFbDCCA1SgAwIBAgIUPgNJgXUWdDGOTKvVxZAplsU5EN0wDQYJKoZIhvcNAQELBQAwTjEL
MAkGA1UEBhMCVVMxEjAQBgNVBAoMCUNvbW1TY29wZTErMCkGA1UEAwwiQ29tbVNjb3BlIFB1
YmxpYyBUcnVzdCBSU0EgUm9vdC0wMTAeFw0yMTA0MjgxNjQ1NTRaFw00NjA0MjgxNjQ1NTNa
ME4xCzAJBgNVBAYTAlVTMRIwEAYDVQQKDAlDb21tU2NvcGUxKzApBgNVBAMMIkNvbW1TY29w
ZSBQdWJsaWMgVHJ1c3QgUlNBIFJvb3QtMDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQCwSGWjDR1C45FtnYSkYZYSwu3D2iM0GXb26v1VWvZVAVMP8syMl0+5UMuzAURWlv2b
KOx7dAvnQmtVzslhsuitQDy6uUEKBU8bJoWPQ7VAtYXR1HHcg0Hz9kXHgKKEUJdGzqAMxGBW
BB0HW0alDrJLpA6lfO741GIDuZNqihS4cPgugkY4Iw50x2tBt9Apo52AsH53k2NC+zSDO3Oj
WiE260f6GBfZumbCk6SP/F2krfxQapWsvCQz0b2If4b19bJzKo98rwjyGpg/qYFlP8GMicWW
MJoKz/TUyDTtnS+8jTiGU+6Xn6myY5QXjQ/cZip8UlF1y5mO6D1cv547KI2DAg+pn3LiLCuz
3GaXAEDQpFSOm117RTYm1nJD68/A6g3czhLmfTifBSeolz7pUcZsBSjBAg/pGG3svZwG1KdJ
9FQFa2ww8esD1eo9anbCyxooSU1/ZOD6K9pzg4H/kQO9lLvkuI6cMmPNn7togbGEW682v3fu
HX/3SZtS7NJ3Wn2RnU3COS3kuoL4b/JOHg9O5j9ZpSPcPYeoKFgo0fEbNttPxP/hjFtyjMcm
AyejOQoBqsCyMWCDIqFPEgkBEa801M/XrmLTBQe0MXXgDW1XT2mH+VepuhX2yFJtocucH+X8
eKg1mp9BFM6ltM6UCBwJrVbl2rZJmkrqYxhTnCwuwwIDAQABo0IwQDAPBgNVHRMBAf8EBTAD
AQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUN12mmnQywsL5x6YVEFm45P3luG0wDQYJ
KoZIhvcNAQELBQADggIBAK+nz97/4L1CjU3lIpbfaOp9TSp90K09FlxD533Ahuh6NWPxzIHI
xgvoLlI1pKZJkGNRrDSsBTtXAOnTYtPZKdVUvhwQkZyybf5Z/Xn36lbQnmhUQo8mUuJM3y+X
pi/SB5io82BdS5pYV4jvguX6r2yBS5KPQJqTRlnLX3gWsWc+QgvfKNmwrZggvkN80V4aCRck
jXtdlemrwWCrWxhkgPut4AZ9HcpZuPN4KWfGVh2vtrV0KnahP/t1MJ+UXjulYPPLXAziDslg
+MkfFoom3ecnf+slpoq9uC02EJqxWE2aaE9gVOX2RhOOiKy8IUISrcZKiX2bwdgt6ZYD9KJ0
DLwAHb/WNyVntHKLr4W96ioDj8z7PEQkguIBpQtZtjSNMgsSDesnwv1B10A8ckYpwIzqug/x
BpMu95yo9GA+o/E4Xo4TwbM6l4c/ksp4qRyv0LAbJh6+cOx69TOY6lz/KwsETkPdY34Op054
A5U+1C0wlREQKC6/oAI+/15Z0wUOlV9TRe9rh9VIzRamloPh37MG88EU26fsHItdkJANclHn
YfkUyq+Dj7+vsQpZXdxc1+SWrVtgHdqul7I52Qb1dgAT+GhMIbA1xNxVssnBQVocicCMb3Sg
azNNtQEo/a2tiRc7ppqEvOuM6sRxJKi6KfkIsidWNTJf6jn7MZrVGczw
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIFbDCCA1SgAwIBAgIUVBa/O345lXGN0aoApYYNK496BU4wDQYJKoZIhvcNAQELBQAwTjEL
MAkGA1UEBhMCVVMxEjAQBgNVBAoMCUNvbW1TY29wZTErMCkGA1UEAwwiQ29tbVNjb3BlIFB1
YmxpYyBUcnVzdCBSU0EgUm9vdC0wMjAeFw0yMTA0MjgxNzE2NDNaFw00NjA0MjgxNzE2NDJa
ME4xCzAJBgNVBAYTAlVTMRIwEAYDVQQKDAlDb21tU2NvcGUxKzApBgNVBAMMIkNvbW1TY29w
ZSBQdWJsaWMgVHJ1c3QgUlNBIFJvb3QtMDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQDh+g77aAASyE3VrCLENQE7xVTlWXZjpX/rwcRqmL0yjReA61260WI9JSMZNRTpf4mn
G2I81lDnNJUDMrG0kyI9p+Kx7eZ7Ti6Hmw0zdQreqjXnfuU2mKKuJZ6VszKWpCtYHu8//mI0
SFHRtI1CrWDaSWqVcN3SAOLMV2MCe5bdSZdbkk6V0/nLKR8YSvgBKtJjCW4k6YnS5cciTNxz
hkcAqg2Ijq6FfUrpuzNPDlJwnZXjfG2WWy09X6GDRl224yW4fKcZgBzqZUPckXk2LHR88mcG
yYnJ27/aaL8j7dxrrSiDeS/sOKUNNwFnJ5rpM9kzXzehxfCrPfp4sOcsn/Y+n2Dg70jpkEUe
BVF4GiwSLFworA2iI540jwXmojPOEXcT1A6kHkIfhs1w/tkuFT0du7jyU1fbzMZ0KZwYszZ1
OC4PVKH4kh+Jlk+71O6d6Ts2QrUKOyrUZHk2EOH5kQMreyBUzQ0ZGshBMjTRsJnhkB4BQDa1
t/qp5Xd1pCKBXbCL5CcSD1SIxtuFdOa3wNemKfrb3vOTlycEVS8KbzfFPROvCgCpLIscgSjX
74Yxqa7ybrjKaixUR9gqiC6vwQcQeKwRoi9C8DfF8rhW3Q5iLc4tVn5V8qdE9isy9COoR+jU
KgF4z2rDN6ieZdIs5fq6M8EGRPbmz6UNp2YINIos8wIDAQABo0IwQDAPBgNVHRMBAf8EBTAD
AQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUR9DnsSL/nSz12Vdgs7GxcJXvYXowDQYJ
KoZIhvcNAQELBQADggIBAIZpsU0v6Z9PIpNojuQhmaPORVMbc0RTAIFhzTHjCLqBKCh6krm2
qMhDnscTJk3C2OVVnJJdUNjCK9v+5qiXz1I6JMNlZFxHMaNlNRPDk7n3+VGXu6TwYofF1gbT
l4MgqX67tiHCpQ2EAOHyJxCDut0DgdXdaMNmEMjRdrSzbymeAPnCKfWxkxlSaRosTKCL4BWa
MS/TiJVZbuXEs1DIFAhKm4sTg7GkcrI7djNB3NyqpgdvHSQSn8h2vS/ZjvQs7rfSOBAkNlEv
41xdgSGn2rtO/+YHqP65DSdsu3BaVXoT6fEqSWnHX4dXTEN5bTpl6TBcQe7rd6VzEojov32u
5cSoHw2OHG1QAk8mGEPej1WFsQs3BWDJVTkSBKEqz3EWnzZRSb9wO55nnPt7eck5HHisd5FU
mrh1CoFSl+NmYWvtPjgelmFV4ZFUjO2MJB+ByRCac5krFk5yAD9UG/iNuovnFNa2RU9g7Jau
wy8CTl2dlklyALKrdVwPaFsdZcJfMw8eD/A7hvWwTruc9+olBdytoptLFwG+Qt81IR2tq670
v64fG9PiO/yzcnMcmyiQiRM9HcEARwmWmjgb3bHPDcK0RPOWlc4yOo80nOAXx17Org3bhzjl
P1v9mxnhMUF6cKojawHhRUzNlM47ni3niAIi9G7oyOzWPPO5std3eqx7
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICQjCCAcmgAwIBAgIQNjqWjMlcsljN0AFdxeVXADAKBggqhkjOPQQDAzBjMQswCQYDVQQG
EwJERTEnMCUGA1UECgweRGV1dHNjaGUgVGVsZWtvbSBTZWN1cml0eSBHbWJIMSswKQYDVQQD
DCJUZWxla29tIFNlY3VyaXR5IFRMUyBFQ0MgUm9vdCAyMDIwMB4XDTIwMDgyNTA3NDgyMFoX
DTQ1MDgyNTIzNTk1OVowYzELMAkGA1UEBhMCREUxJzAlBgNVBAoMHkRldXRzY2hlIFRlbGVr
b20gU2VjdXJpdHkgR21iSDErMCkGA1UEAwwiVGVsZWtvbSBTZWN1cml0eSBUTFMgRUNDIFJv
b3QgMjAyMDB2MBAGByqGSM49AgEGBSuBBAAiA2IABM6//leov9Wq9xCazbzREaK9Z0LMkOsV
GJDZos0MKiXrPk/OtdKPD/M12kOLAoC+b1EkHQ9rK8qfwm9QMuU3ILYg/4gND21Ju9sGpIeQ
kpT0CdDPf8iAC8GXs7s1J8nCG6NCMEAwHQYDVR0OBBYEFONyzG6VmUex5rNhTNHLq+O6zd6f
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2cAMGQCMHVS
i7ekEE+uShCLsoRbQuHmKjYC2qBuGT8lv9pZMo7k+5Dck2TOrbRBR2Diz6fLHgIwN0GMZt9B
a9aDAEH9L1r3ULRn0SyocddDypwnJJGDSA3PzfdUga/sf+Rn27iQ7t0l
-----END CERTIFICATE-----        -----BEGIN CERTIFICATE-----
MIIFszCCA5ugAwIBAgIQIZxULej27HF3+k7ow3BXlzANBgkqhkiG9w0BAQwFADBjMQswCQYD
VQQGEwJERTEnMCUGA1UECgweRGV1dHNjaGUgVGVsZWtvbSBTZWN1cml0eSBHbWJIMSswKQYD
VQQDDCJUZWxla29tIFNlY3VyaXR5IFRMUyBSU0EgUm9vdCAyMDIzMB4XDTIzMDMyODEyMTY0
NVoXDTQ4MDMyNzIzNTk1OVowYzELMAkGA1UEBhMCREUxJzAlBgNVBAoMHkRldXRzY2hlIFRl
bGVrb20gU2VjdXJpdHkgR21iSDErMCkGA1UEAwwiVGVsZWtvbSBTZWN1cml0eSBUTFMgUlNB
IFJvb3QgMjAyMzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAO01oYGA88tKaVvC
+1GDrib94W7zgRJ9cUD/h3VCKSHtgVIs3xLBGYSJwb3FKNXVS2xE1kzbB5ZKVXrKNoIENqil
/Cf2SfHVcp6R+SPWcHu79ZvB7JPPGeplfohwoHP89v+1VmLhc2o0mD6CuKyVU/QBoCcHcqMA
U6DksquDOFczJZSfvkgdmOGjup5czQRxUX11eKvzWarE4GC+j4NSuHUaQTXtvPM6Y+mpFEXX
5lLRbtLevOP1Czvm4MS9Q2QTps70mDdsipWol8hHD/BeEIvnHRz+sTugBTNoBUGCwQMrAcjn
j02r6LX2zWtEtefdi+zqJbQAIldNsLGyMcEWzv/9FIS3R/qy8XDe24tsNlikfLMR0cN3f1+2
JeANxdKz+bi4d9s3cXFH42AYTyS2dTd4uaNir73Jco4vzLuu2+QVUhkHM/tqty1LkCiCc/4Y
izWN26cEar7qwU02OxY2kTLvtkCJkUPg8qKrBC7m8kwOFjQgrIfBLX7JZkcXFBGk8/ehJImr
2BrIoVyxo/eMbcgByU/J7MT8rFEz0ciD0cmfHdRHNCk+y7AO+oMLKFjlKdw/fKifybYKu6bo
RhYPluV75Gp6SG12mAWl3G0eQh5C2hrgUve1g8Aae3g1LDj1H/1Joy7SWWO/gLCMk3PLNaaZ
lSJhZQNg+y+TS/qanIA7AgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUtqeX
gj10hZv3PJ+TmpV5dVKMbUcwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBS2p5eCPXSF
m/c8n5OalXl1UoxtRzANBgkqhkiG9w0BAQwFAAOCAgEAqMxhpr51nhVQpGv7qHBFfLp+sVr8
WyP6Cnf4mHGCDG3gXkaqk/QeoMPhk9tLrbKmXauw1GLLXrtm9S3ul0A8Yute1hTWjOKWi0Fp
kzXmuZlrYrShF2Y0pmtjxrlO8iLpWA1WQdH6DErwM807u20hOq6OcrXDSvvpfeWxm4bu4uB9
tPcy/SKE8YXJN3nptT+/XOR0so8RYgDdGGah2XsjX/GO1WfoVNpbOms2b/mBsTNHM3dA+VKq
3dSDz4V4mZqTuXNnQkYRIer+CqkbGmVps4+uFrb2S1ayLfmlyOw7YqPta9BO1UAJpB+Y1zql
klkg5LB9zVtzaL1txKITDmcZuI1CfmwMmm6gJC3VRRvcxAIU/oVbZZfKTpBQCHpCNfnqwmbU
+AGuHrS+w6jv/naaoqYfRvaE7fzbzsQCzndILIyy7MMAo+wsVRjBfhnu4S/yrYObnqsZ38aK
L4x35bcF7DvB7L6Gs4a8wPfc5+pbrrLMtTWGS9DiP7bY+A4A7l3j941Y/8+LN+ljX273CXE2
whJdV/LItM3z7gLfEdxquVeEHVlNjM7IDiPCtyaaEBRx/pOyiriA8A4QntOoUAw3gi/q4Iqd
4Sw5/7W0cwDk90imc6y/st53BIe0o82bNSQ3+pCTE4FCxpgmdTdmQRCsu/WU48IxK63nI1bM
NSWSs1A=
-----END CERTIFICATE-----       -----BEGIN CERTIFICATE-----
MIICejCCAgCgAwIBAgIQMZch7a+JQn81QYehZ1ZMbTAKBggqhkjOPQQDAzBuMQswCQYDVQQG
EwJFUzEcMBoGA1UECgwTRmlybWFwcm9mZXNpb25hbCBTQTEYMBYGA1UEYQwPVkFURVMtQTYy
NjM0MDY4MScwJQYDVQQDDB5GSVJNQVBST0ZFU0lPTkFMIENBIFJPT1QtQSBXRUIwHhcNMjIw
NDA2MDkwMTM2WhcNNDcwMzMxMDkwMTM2WjBuMQswCQYDVQQGEwJFUzEcMBoGA1UECgwTRmly
bWFwcm9mZXNpb25hbCBTQTEYMBYGA1UEYQwPVkFURVMtQTYyNjM0MDY4MScwJQYDVQQDDB5G
SVJNQVBST0ZFU0lPTkFMIENBIFJPT1QtQSBXRUIwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAARH
U+osEaR3xyrq89Zfe9MEkVz6iMYiuYMQYneEMy3pA4jU4DP37XcsSmDq5G+tbbT4TIqk5B/K
6k84Si6CcyvHZpsKjECcfIr28jlgst7L7Ljkb+qbXbdTkBgyVcUgt5SjYzBhMA8GA1UdEwEB
/wQFMAMBAf8wHwYDVR0jBBgwFoAUk+FDY1w8ndYn81LsF7Kpryz3dvgwHQYDVR0OBBYEFJPh
Q2NcPJ3WJ/NS7Beyqa8s93b4MA4GA1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNoADBlAjAd
fKR7w4l1M+E7qUW/Runpod3JIha3RxEL2Jq68cgLcFBTApFwhVmpHqTm6iMxoAACMQD94viz
rxa5HnPEluPBMBnYfubDl94cT7iJLzPrSA8Z94dGXSaQpYXFuXqUPoeovQA=
-----END CERTIFICATE-----   -----BEGIN CERTIFICATE-----
MIIFjTCCA3WgAwIBAgIQQAE0jMIAAAAAAAAAATzyxjANBgkqhkiG9w0BAQwFADBQMQswCQYD
VQQGEwJUVzESMBAGA1UEChMJVEFJV0FOLUNBMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQD
ExJUV0NBIENZQkVSIFJvb3QgQ0EwHhcNMjIxMTIyMDY1NDI5WhcNNDcxMTIyMTU1OTU5WjBQ
MQswCQYDVQQGEwJUVzESMBAGA1UEChMJVEFJV0FOLUNBMRAwDgYDVQQLEwdSb290IENBMRsw
GQYDVQQDExJUV0NBIENZQkVSIFJvb3QgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQDG+Moe2Qkgfh1sTs6P40czRJzHyWmqOlt47nDSkvgEs1JSHWdyKKHfi12VCv7qze33
Kc7wb3+szT3vsxxFavcokPFhV8UMxKNQXd7UtcsZyoC5dc4pztKFIuwCY8xEMCDa6pFbVuYd
HNWdZsc/34bKS1PE2Y2yHer43CdTo0fhYcx9tbD47nORxc5zb87uEB8aBs/pJ2DFTxnk684i
JkXXYJndzk834H/nY62wuFm40AZoNWDTNq5xQwTxaWV4fPMf88oon1oglWa0zbfuj3ikRRjp
Ji+NmykosaS3Om251Bw4ckVYsV7r8Cibt4LK/c/WMw+f+5eesRycnupfXtuq3VTpMCEobY55
83WSjCb+3MX2w7DfRFlDo7YDKPYIMKoNM+HvnKkHIuNZW0CP2oi3aQiotyMuRAlZN1vH4xfy
IutuOVLF3lSnmMlLIJXcRolftBL5hSmO68gnFSDAS9TMfAxsNAwmmyYxpjyn9tnQS6Jk/zuZ
QXLB4HCX8SS7K8R0IrGsayIyJNN4KsDAoS/xUgXJP+92ZuJF2A09rZXIx4kmyA+upwMu+8Ff
+iDhcK2wZSA3M2Cw1a/XDBzCkHDXShi8fgGwsOsVHkQGzaRP6AzRwyAQ4VRlnrZR0Bp2a0Ja
WHY06rc3Ga4udfmW5cFZ95RXKSWNOkyrTZpB0F8mAwIDAQABo2MwYTAOBgNVHQ8BAf8EBAMC
AQYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBSdhWEUfMFib5do5E83QOGt4A1WNzAd
BgNVHQ4EFgQUnYVhFHzBYm+XaORPN0DhreANVjcwDQYJKoZIhvcNAQEMBQADggIBAGSPesRi
DrWIzLjHhg6hShbNcAu3p4ULs3a2D6f/CIsLJc+o1IN1KriWiLb73y0ttGlTITVX1olNc79p
j3CjYcya2x6a4CD4bLubIp1dhDGaLIrdaqHXKGnK/nZVekZn68xDiBaiA9a5F/gZbG0jAn/x
X9AKKSM70aoK7akXJlQKTcKlTfjF/biBzysseKNnTKkHmvPfXvt89YnNdJdhEGoHK4Fa0o63
5yDRIG4kqIQnoVesqlVYL9zZyvpoBJ7tRCT5dEA7IzOrg1oYJkK2bVS1FmAwbLGg+LhBoF1J
SdJlBTrq/p1hvIbZv97Tujqxf36SNI7JAG7cmL3c7IAFrQI932XtCwP39xaEBDG6k5TY8hL4
iuO/Qq+n1M0RFxbIQh0UqEL20kCGoE8jypZFVmAGzbdVAaYBlGX+bgUJurSkquLvWL69J1bY
73NxW0Qz8ppy6rBePm6pUlvscG21h483XjyMnM7k8M4MZ0HMzvaAq07MTFb1wWFZk7Q+ptq4
NxKfKjLji7gh7MMrZQzvIt6IKTtM1/r+t+FHvpw+PoP7UV31aPcuIYXcv/Fa4nzXxeSDwWrr
uoBa3lwtcHb4yOWHh8qgnaHlIhInD0Q9HWzq1MKLL295q39QpsQZp6F6t5b5wR9iWqJDB0Be
Jsas7a5wFsWqynKKTbDPAYsDP27X
-----END CERTIFICATE-----    -----BEGIN CERTIFICATE-----
MIIDcjCCAlqgAwIBAgIUZvnHwa/swlG07VOX5uaCwysckBYwDQYJKoZIhvcNAQELBQAwUTEL
MAkGA1UEBhMCSlAxIzAhBgNVBAoTGkN5YmVydHJ1c3QgSmFwYW4gQ28uLCBMdGQuMR0wGwYD
VQQDExRTZWN1cmVTaWduIFJvb3QgQ0ExMjAeFw0yMDA0MDgwNTM2NDZaFw00MDA0MDgwNTM2
NDZaMFExCzAJBgNVBAYTAkpQMSMwIQYDVQQKExpDeWJlcnRydXN0IEphcGFuIENvLiwgTHRk
LjEdMBsGA1UEAxMUU2VjdXJlU2lnbiBSb290IENBMTIwggEiMA0GCSqGSIb3DQEBAQUAA4IB
DwAwggEKAoIBAQC6OcE3emhFKxS06+QT61d1I02PJC0W6K6OyX2kVzsqdiUzg2zqMoqUm048
luT9Ub+ZyZN+v/mtp7JIKwccJ/VMvHASd6SFVLX9kHrko+RRWAPNEHl57muTH2SOa2SroxPj
cf59q5zdJ1M3s6oYwlkm7Fsf0uZlfO+TvdhYXAvA42VvPMfKWeP+bl+sg779XSVOKik71gur
FzJ4pOE+lEa+Ym6b3kaosRbnhW70CEBFEaCeVESE99g2zvVQR9wsMJvuwPWW0v4JhscGWa5P
ro4RmHvzC1KqYiaqId+OJTN5lxZJjfU+1UefNzFJM3IFTQy2VYzxV4+Kh9GtxRESOaCtAgMB
AAGjQjBAMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBRXNPN0
zwRL1SXm8UC2LEzZLemgrTANBgkqhkiG9w0BAQsFAAOCAQEAPrvbFxbS8hQBICw4g0utvsqF
epq2m2um4fylOqyttCg6r9cBg0krY6LdmmQOmFxv3Y67ilQiLUoT865AQ9tPkbeGGuwAtEGB
pE/6aouIs3YIcipJQMPTw4WJmBClnW8Zt7vPemVV2zfrPIpyMpcemik+rY3moxtt9XUa5rBo
uVui7mlHJzWhhpmA8zNL4WukJsPvdFlseqJkth5Ew1DgDzk9qTPxpfPSvWKErI4cqc1avTc7
bgoitPQV55FYxTpE05Uo2cBl6XLK0A+9H7MV2anjpEcJnuDLN/v9vZfVvhgaaaI5gdka9at/
yOPiZwud9AzqVN/Ssq+xIvEg37xEHA==
-----END CERTIFICATE-----  -----BEGIN CERTIFICATE-----
MIIFcjCCA1qgAwIBAgIUZNtaDCBO6Ncpd8hQJ6JaJ90t8sswDQYJKoZIhvcNAQEMBQAwUTEL
MAkGA1UEBhMCSlAxIzAhBgNVBAoTGkN5YmVydHJ1c3QgSmFwYW4gQ28uLCBMdGQuMR0wGwYD
VQQDExRTZWN1cmVTaWduIFJvb3QgQ0ExNDAeFw0yMDA0MDgwNzA2MTlaFw00NTA0MDgwNzA2
MTlaMFExCzAJBgNVBAYTAkpQMSMwIQYDVQQKExpDeWJlcnRydXN0IEphcGFuIENvLiwgTHRk
LjEdMBsGA1UEAxMUU2VjdXJlU2lnbiBSb290IENBMTQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
DwAwggIKAoICAQDF0nqh1oq/FjHQmNE6lPxauG4iwWL3pwon71D2LrGeaBLwbCRjOfHw3xDG
3rdSINVSW0KZnvOgvlIfX8xnbacuUKLBl422+JX1sLrcneC+y9/3OPJH9aaakpUqYllQC6Kx
NedlsmGy6pJxaeQp8E+BgQQ8sqVb1MWoWWd7VRxJq3qdwudzTe/NCcLEVxLbAQ4jeQkHO6Lo
/IrPj8BGJJw4J+CDnRugv3gVEOuGTgpa/d/aLIJ+7sr2KeH6caH3iGicnPCNvg9JkdjqOvn9
0Ghx2+m1K06Ckm9mH+Dw3EzsytHqunQG+bOEkJTRX45zGRBdAuVwpcAQ0BB8b8VYSbSwbpra
fZX1zNoCr7gsfXmPvkPx+SgojQlD+Ajda8iLLCSxjVIHvXiby8posqTdDEx5YMaZ0ZPxMBoH
064iwurO8YQJzOAUbn8/ftKChazcqRZOhaBgy/ac18izju3Gm5h1DVXoX+WViwKkrkMpKBGk
5hIwAUt1ax5mnXkvpXYvHUC0bcl9eQjs0Wq2XSqypWa9a4X0dFbD9ed1Uigspf9mR6XU/v6e
VL9lfgHWMI+lNpyiUBzuOIABSMbHdPTGrMNASRZhdCyvjG817XsYAFs2PJxQDcqSMxDxJklt
33UkN4Ii1+iW/RVLApY+B3KVfqs9TC7XyvDf4Fg/LS8EmjijAQIDAQABo0IwQDAPBgNVHRMB
Af8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUBpOjCl4oaTeqYR3r6/wtbyPk
86AwDQYJKoZIhvcNAQEMBQADggIBAJaAcgkGfpzMkwQWu6A6jZJOtxEaCnFxEM0ErX+lRVAQ
Zk5KQaID2RFPeje5S+LGjzJmdSX7684/AykmjbgWHfYfM25I5uj4V7Ibed87hwriZLoAymzv
ftAj63iP/2SbNDefNWWipAA9EiOWWF3KY4fGoweITedpdopTzfFP7ELyk+OZpDc8h7hi2/Ds
Hzc/N19DzFGdtfCXwreFamgLRB7lUe6TzktuhsHSDCRZNhqfLJGP4xjblJUK7ZGqDpncllPj
YYPGFrojutzdfhrGe0K22VoF3Jpf1d+42kd92jjbrDnVHmtsKheMYc2xbXIBw8MgAGJoFjHV
dqqGuw6qnsb58Nn4DSEC5MUoFlkRudlpcyqSeLiSV5sI8jrlL5WwWLdrIBRtFO8KvH7YVdiI
2i/6GaX7i+B/OfVyK4XELKzvGUWSTLNhB9xNH27SgRNcmvMSZ4PPmz+Ln52kuaiWA3rF7iDe
M9ovnhp6dB7h7sxaOgTdsxoEqBRjrLdHEoOabPXm6RUVkRqEGQ6UROcSjiVbgGcZ3GOTEAtl
Lor6CZpO2oYofaphNdgOpygau1LgePhsumywbrmHXumZNTfxPWQrqaA0k89jL9WB365jJ6Ue
To3cKXhZ+PmhIIynJkBugnLNeLLIjzwec+fBH7/PzqUqm9tEZDKgu39cJRNItX+S
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIICIzCCAamgAwIBAgIUFhXHw9hJp75pDIqI7fBw+d23PocwCgYIKoZIzj0EAwMwUTELMAkG
A1UEBhMCSlAxIzAhBgNVBAoTGkN5YmVydHJ1c3QgSmFwYW4gQ28uLCBMdGQuMR0wGwYDVQQD
ExRTZWN1cmVTaWduIFJvb3QgQ0ExNTAeFw0yMDA0MDgwODMyNTZaFw00NTA0MDgwODMyNTZa
MFExCzAJBgNVBAYTAkpQMSMwIQYDVQQKExpDeWJlcnRydXN0IEphcGFuIENvLiwgTHRkLjEd
MBsGA1UEAxMUU2VjdXJlU2lnbiBSb290IENBMTUwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQL
UHSNZDKZmbPSYAi4Io5GdCx4wCtELW1fHcmuS1Iggz24FG1Th2CeX2yF2wYUleDHKP+dX+Sq
8bOLbe1PL0vJSpSRZHX+AezB2Ot6lHhWGENfa4HL9rzatAy2KZMIaY+jQjBAMA8GA1UdEwEB
/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBTrQciu/NWeUUj1vYv0hyCTQSvT
9DAKBggqhkjOPQQDAwNoADBlAjEA2S6Jfl5OpBEHvVnCB96rMjhTKkZEBhd6zlHp4P9mLQlO
4E/0BdGF9jVg3PVys0Z9AjBEmEYagoUeYWmJSwdLZrWeqrqgHkHZAXQ6bkU6iYAZezKYVWOr
62Nuk22rGwlgMU4=
-----END CERTIFICATE-----                        2   =   :                      entry      Z           core:user:                      	   Z                   MF-CF-Blob      *:8080           7                   �      z-         �2  r   �2  �� miniflare:shared        // src/workers/shared/blob.worker.ts
import assert from "node-internal:internal_assert";
import { Buffer as Buffer2 } from "node-internal:internal_buffer";

// src/workers/shared/data.ts
import { Buffer } from "node-internal:internal_buffer";
function viewToBuffer(view) {
  return view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength);
}
function base64Encode(value) {
  return Buffer.from(value, "utf8").toString("base64");
}
function base64Decode(encoded) {
  return Buffer.from(encoded, "base64").toString("utf8");
}
var dotRegexp = /(^|\/|\\)(\.+)(\/|\\|$)/g, illegalRegexp = /[?<>*"'^/\\:|\x00-\x1f\x80-\x9f]/g, windowsReservedRegexp = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$/i, leadingRegexp = /^[ /\\]+/, trailingRegexp = /[ /\\]+$/;
function dotReplacement(match, g1, g2, g3) {
  return `${g1}${"".padStart(g2.length, "_")}${g3}`;
}
function underscoreReplacement(match) {
  return "".padStart(match.length, "_");
}
function sanitisePath(unsafe) {
  return unsafe.replace(dotRegexp, dotReplacement).replace(dotRegexp, dotReplacement).replace(illegalRegexp, "_").replace(windowsReservedRegexp, "_").replace(leadingRegexp, underscoreReplacement).replace(trailingRegexp, underscoreReplacement).substring(0, 255);
}

// src/workers/shared/blob.worker.ts
var ENCODER = new TextEncoder();
async function readPrefix(stream, prefixLength) {
  let reader = await stream.getReader({ mode: "byob" }), result = await reader.readAtLeast(
    prefixLength,
    new Uint8Array(prefixLength)
  );
  assert(result.value !== void 0), reader.releaseLock();
  let rest = stream.pipeThrough(new IdentityTransformStream());
  return [result.value, rest];
}
function rangeHeaders(range) {
  return { Range: `bytes=${range.start}-${range.end}` };
}
function assertFullRangeRequest(range, contentLength) {
  assert(
    range.start === 0 && range.end === contentLength - 1,
    "Received full content, but requested partial content"
  );
}
async function fetchSingleRange(fetcher, url, range) {
  let headers = range === void 0 ? {} : rangeHeaders(range), res = await fetcher.fetch(url, { headers });
  if (res.status === 404)
    return null;
  if (assert(res.ok && res.body !== null), range !== void 0 && res.status !== 206) {
    let contentLength = parseInt(res.headers.get("Content-Length"));
    assert(!Number.isNaN(contentLength)), assertFullRangeRequest(range, contentLength);
  }
  return res.body;
}
async function writeMultipleRanges(fetcher, url, ranges, boundary, writable, contentLength, contentType) {
  for (let i = 0; i < ranges.length; i++) {
    let range = ranges[i], writer2 = writable.getWriter();
    i > 0 && await writer2.write(ENCODER.encode(`\r
`)), await writer2.write(ENCODER.encode(`--${boundary}\r
`)), contentType !== void 0 && await writer2.write(ENCODER.encode(`Content-Type: ${contentType}\r
`));
    let start = range.start, end = Math.min(range.end, contentLength - 1);
    await writer2.write(
      ENCODER.encode(
        `Content-Range: bytes ${start}-${end}/${contentLength}\r
\r
`
      )
    ), writer2.releaseLock();
    let res = await fetcher.fetch(url, { headers: rangeHeaders(range) });
    assert(
      res.ok && res.body !== null,
      `Failed to fetch ${url}[${range.start},${range.end}], received ${res.status} ${res.statusText}`
    ), res.status !== 206 && assertFullRangeRequest(range, contentLength), await res.body.pipeTo(writable, { preventClose: !0 });
  }
  let writer = writable.getWriter();
  ranges.length > 0 && await writer.write(ENCODER.encode(`\r
`)), await writer.write(ENCODER.encode(`--${boundary}--`)), await writer.close();
}
async function fetchMultipleRanges(fetcher, url, ranges, opts) {
  let res = await fetcher.fetch(url, { method: "HEAD" });
  if (res.status === 404)
    return null;
  assert(res.ok);
  let contentLength = parseInt(res.headers.get("Content-Length"));
  assert(!Number.isNaN(contentLength));
  let boundary = `miniflare-boundary-${crypto.randomUUID()}`, multipartContentType = `multipart/byteranges; boundary=${boundary}`, { readable, writable } = new IdentityTransformStream();
  return writeMultipleRanges(
    fetcher,
    url,
    ranges,
    boundary,
    writable,
    contentLength,
    opts?.contentType
  ).catch((e) => console.error("Error writing multipart stream:", e)), { multipartContentType, body: readable };
}
async function fetchRange(fetcher, url, range, opts) {
  return Array.isArray(range) ? fetchMultipleRanges(fetcher, url, range, opts) : fetchSingleRange(fetcher, url, range);
}
function generateBlobId() {
  let idBuffer = Buffer2.alloc(40);
  return crypto.getRandomValues(
    new Uint8Array(idBuffer.buffer, idBuffer.byteOffset, 32)
  ), idBuffer.writeBigInt64BE(
    BigInt(performance.timeOrigin + performance.now()),
    32
  ), idBuffer.toString("hex");
}
var BlobStore = class {
  // Database for binary large objects. Provides single and multi-ranged
  // streaming reads and writes.
  //
  // Blobs have unguessable identifiers, can be deleted, but are otherwise
  // immutable. These properties make it possible to perform atomic updates with
  // the SQLite metadata store. No other operations will be able to interact
  // with the blob until it's committed to the metadata store, because they
  // won't be able to guess the ID, and we don't allow listing blobs.
  //
  // For example, if we put a blob in the store, then fail to insert the blob ID
  // into the SQLite database for some reason during a transaction (e.g.
  // `onlyIf` condition failed), no other operations can read that blob because
  // the ID is lost (we'll just background-delete the blob in this case).
  #fetcher;
  #baseURL;
  #stickyBlobs;
  constructor(fetcher, namespace, stickyBlobs) {
    namespace = encodeURIComponent(sanitisePath(namespace)), this.#fetcher = fetcher, this.#baseURL = `http://placeholder/${namespace}/blobs/`, this.#stickyBlobs = stickyBlobs;
  }
  idURL(id) {
    let url = new URL(this.#baseURL + id);
    return url.toString().startsWith(this.#baseURL) ? url : null;
  }
  async get(id, range, opts) {
    let idURL = this.idURL(id);
    return idURL === null ? null : fetchRange(this.#fetcher, idURL, range, opts);
  }
  async put(stream) {
    let id = generateBlobId(), idURL = this.idURL(id);
    return assert(idURL !== null), await this.#fetcher.fetch(idURL, {
      method: "PUT",
      body: stream
    }), id;
  }
  async delete(id) {
    if (this.#stickyBlobs)
      return;
    let idURL = this.idURL(id);
    if (idURL === null)
      return;
    let res = await this.#fetcher.fetch(idURL, { method: "DELETE" });
    assert(res.ok || res.status === 404);
  }
};

// src/workers/shared/constants.ts
var SharedHeaders = {
  LOG_LEVEL: "MF-Log-Level"
}, SharedBindings = {
  TEXT_NAMESPACE: "MINIFLARE_NAMESPACE",
  DURABLE_OBJECT_NAMESPACE_OBJECT: "MINIFLARE_OBJECT",
  MAYBE_SERVICE_BLOBS: "MINIFLARE_BLOBS",
  MAYBE_SERVICE_LOOPBACK: "MINIFLARE_LOOPBACK",
  MAYBE_JSON_ENABLE_CONTROL_ENDPOINTS: "MINIFLARE_ENABLE_CONTROL_ENDPOINTS",
  MAYBE_JSON_ENABLE_STICKY_BLOBS: "MINIFLARE_STICKY_BLOBS"
}, LogLevel = /* @__PURE__ */ ((LogLevel3) => (LogLevel3[LogLevel3.NONE = 0] = "NONE", LogLevel3[LogLevel3.ERROR = 1] = "ERROR", LogLevel3[LogLevel3.WARN = 2] = "WARN", LogLevel3[LogLevel3.INFO = 3] = "INFO", LogLevel3[LogLevel3.DEBUG = 4] = "DEBUG", LogLevel3[LogLevel3.VERBOSE = 5] = "VERBOSE", LogLevel3))(LogLevel || {});

// src/workers/shared/keyvalue.worker.ts
import assert3 from "node-internal:internal_assert";

// src/workers/shared/sql.worker.ts
import assert2 from "node-internal:internal_assert";
function isTypedValue(value) {
  return value === null || typeof value == "string" || typeof value == "number" || value instanceof ArrayBuffer;
}
function createStatementFactory(sql) {
  return (query) => {
    let keyIndices = /* @__PURE__ */ new Map();
    query = query.replace(/[:@$]([a-z0-9_]+)/gi, (_, name) => {
      let index = keyIndices.get(name);
      return index === void 0 && (index = keyIndices.size, keyIndices.set(name, index)), `?${index + 1}`;
    });
    let stmt = sql.prepare(query);
    return (argsObject) => {
      let entries = Object.entries(argsObject);
      assert2.strictEqual(
        entries.length,
        keyIndices.size,
        "Expected same number of keys in bindings and query"
      );
      let argsArray = new Array(entries.length);
      for (let [key, value] of entries) {
        let index = keyIndices.get(key);
        assert2(index !== void 0, `Unexpected binding key: ${key}`), argsArray[index] = value;
      }
      return stmt(...argsArray);
    };
  };
}
function createTransactionFactory(storage) {
  return (closure) => (...args) => storage.transactionSync(() => closure(...args));
}
function createTypedSql(storage) {
  let sql = storage.sql;
  return sql.stmt = createStatementFactory(sql), sql.txn = createTransactionFactory(storage), sql;
}
function get(cursor) {
  let result;
  for (let row of cursor)
    result ??= row;
  return result;
}
function all(cursor) {
  return Array.from(cursor);
}
function drain(cursor) {
  for (let _ of cursor)
    ;
}

// src/workers/shared/keyvalue.worker.ts
var SQL_SCHEMA = `
CREATE TABLE IF NOT EXISTS _mf_entries (
  key TEXT PRIMARY KEY,
  blob_id TEXT NOT NULL,
  expiration INTEGER,
  metadata TEXT
);
CREATE INDEX IF NOT EXISTS _mf_entries_expiration_idx ON _mf_entries(expiration);
`;
function sqlStmts(db) {
  let stmtGetBlobIdByKey = db.stmt(
    "SELECT blob_id FROM _mf_entries WHERE key = :key"
  ), stmtPut = db.stmt(
    `INSERT OR REPLACE INTO _mf_entries (key, blob_id, expiration, metadata)
    VALUES (:key, :blob_id, :expiration, :metadata)`
  );
  return {
    getByKey: db.prepare(
      "SELECT key, blob_id, expiration, metadata FROM _mf_entries WHERE key = ?1"
    ),
    put: db.txn((newEntry) => {
      let key = newEntry.key, previousEntry = get(stmtGetBlobIdByKey({ key }));
      return stmtPut(newEntry), previousEntry?.blob_id;
    }),
    deleteByKey: db.stmt(
      "DELETE FROM _mf_entries WHERE key = :key RETURNING blob_id, expiration"
    ),
    deleteExpired: db.stmt(
      // `expiration` may be `NULL`, but `NULL < ...` should be falsy
      "DELETE FROM _mf_entries WHERE expiration < :now RETURNING blob_id"
    ),
    list: db.stmt(
      `SELECT key, expiration, metadata FROM _mf_entries
        WHERE substr(key, 1, length(:prefix)) = :prefix
        AND key > :start_after
        AND (expiration IS NULL OR expiration >= :now)
        ORDER BY key LIMIT :limit`
    )
  };
}
function rowEntry(entry) {
  return {
    key: entry.key,
    expiration: entry.expiration ?? void 0,
    metadata: entry.metadata === null ? void 0 : JSON.parse(entry.metadata)
  };
}
var KeyValueStorage = class {
  #stmts;
  #blob;
  #timers;
  constructor(object) {
    object.db.exec("PRAGMA case_sensitive_like = TRUE"), object.db.exec(SQL_SCHEMA), this.#stmts = sqlStmts(object.db), this.#blob = object.blob, this.#timers = object.timers;
  }
  #hasExpired(entry) {
    return entry.expiration !== null && entry.expiration <= this.#timers.now();
  }
  #backgroundDelete(blobId) {
    this.#timers.queueMicrotask(
      () => this.#blob.delete(blobId).catch(() => {
      })
    );
  }
  async get(key, optsFactory) {
    let row = get(this.#stmts.getByKey(key));
    if (row === void 0)
      return null;
    if (this.#hasExpired(row))
      return drain(this.#stmts.deleteByKey({ key })), this.#backgroundDelete(row.blob_id), null;
    let entry = rowEntry(row), opts = entry.metadata && optsFactory?.(entry.metadata);
    if (opts?.ranges === void 0 || opts.ranges.length <= 1) {
      let value = await this.#blob.get(row.blob_id, opts?.ranges?.[0]);
      return value === null ? null : { ...entry, value };
    } else {
      let value = await this.#blob.get(row.blob_id, opts.ranges, opts);
      return value === null ? null : { ...entry, value };
    }
  }
  async put(entry) {
    assert3(entry.key !== "");
    let blobId = await this.#blob.put(entry.value);
    entry.signal?.aborted && (this.#backgroundDelete(blobId), entry.signal.throwIfAborted());
    let maybeOldBlobId = this.#stmts.put({
      key: entry.key,
      blob_id: blobId,
      expiration: entry.expiration ?? null,
      metadata: entry.metadata === void 0 ? null : JSON.stringify(await entry.metadata)
    });
    maybeOldBlobId !== void 0 && this.#backgroundDelete(maybeOldBlobId);
  }
  async delete(key) {
    let cursor = this.#stmts.deleteByKey({ key }), row = get(cursor);
    return row === void 0 ? !1 : (this.#backgroundDelete(row.blob_id), !this.#hasExpired(row));
  }
  async list(opts) {
    let now = this.#timers.now(), prefix = opts.prefix ?? "", start_after = opts.cursor === void 0 ? "" : base64Decode(opts.cursor), limit = opts.limit + 1, rowsCursor = this.#stmts.list({
      now,
      prefix,
      start_after,
      limit
    }), rows = Array.from(rowsCursor), expiredRows = this.#stmts.deleteExpired({ now });
    for (let row of expiredRows)
      this.#backgroundDelete(row.blob_id);
    let hasMoreRows = rows.length === opts.limit + 1;
    rows.splice(opts.limit, 1);
    let keys = rows.map((row) => rowEntry(row)), nextCursor = hasMoreRows ? base64Encode(rows[opts.limit - 1].key) : void 0;
    return { keys, cursor: nextCursor };
  }
};

// src/workers/shared/matcher.ts
function testRegExps(matcher, value) {
  for (let exclude of matcher.exclude)
    if (exclude.test(value))
      return !1;
  for (let include of matcher.include)
    if (include.test(value))
      return !0;
  return !1;
}

// src/workers/shared/object.worker.ts
import assert5 from "node-internal:internal_assert";

// src/workers/shared/router.worker.ts
var HttpError = class extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    Object.setPrototypeOf(this, new.target.prototype), this.name = `${new.target.name} [${code}]`;
  }
  toResponse() {
    return new Response(this.message, {
      status: this.code,
      // Custom statusMessage is required for runtime error messages
      statusText: this.message.substring(0, 512)
    });
  }
}, kRoutesTemplate = Symbol("kRoutesTemplate"), Router = class {
  // Routes added by @METHOD decorators
  #routes;
  constructor() {
    this.#routes = new.target.prototype[kRoutesTemplate];
  }
  async fetch(req) {
    let url = new URL(req.url), methodRoutes = this.#routes?.get(req.method);
    if (methodRoutes === void 0)
      return new Response(null, { status: 405 });
    let handlers = this;
    try {
      for (let [path, key] of methodRoutes) {
        let match = path.exec(url.pathname);
        if (match !== null)
          return await handlers[key](req, match.groups, url);
      }
      return new Response(null, { status: 404 });
    } catch (e) {
      if (e instanceof HttpError)
        return e.toResponse();
      throw e;
    }
  }
};
function pathToRegexp(path) {
  return path === void 0 ? /^.*$/ : (path.endsWith("/") || (path += "/?"), path = path.replace(/\//g, "\\/"), path = path.replace(/:(\w+)/g, "(?<$1>[^\\/]+)"), new RegExp(`^${path}$`));
}
var createRouteDecorator = (method) => (path) => (prototype, key) => {
  let route = [pathToRegexp(path), key], routes = prototype[kRoutesTemplate] ??= /* @__PURE__ */ new Map(), methodRoutes = routes.get(method);
  methodRoutes ? methodRoutes.push(route) : routes.set(method, [route]);
}, GET = createRouteDecorator("GET"), HEAD = createRouteDecorator("HEAD"), POST = createRouteDecorator("POST"), PUT = createRouteDecorator("PUT"), DELETE = createRouteDecorator("DELETE"), PURGE = createRouteDecorator("PURGE"), PATCH = createRouteDecorator("PATCH");

// src/workers/shared/timers.worker.ts
import assert4 from "node-internal:internal_assert";
var kFakeTimerHandle = Symbol("kFakeTimerHandle"), Timers = class {
  // Fake unix time in milliseconds. If defined, fake timers will be enabled.
  #fakeTimestamp;
  #fakeNextTimerHandle = 0;
  #fakePendingTimeouts = /* @__PURE__ */ new Map();
  #fakeRunningTasks = /* @__PURE__ */ new Set();
  // Timers API
  now = () => this.#fakeTimestamp ?? Date.now();
  setTimeout(closure, delay, ...args) {
    if (this.#fakeTimestamp === void 0)
      return setTimeout(closure, delay, ...args);
    let handle = this.#fakeNextTimerHandle++, argsClosure = () => closure(...args);
    if (delay === 0)
      this.queueMicrotask(argsClosure);
    else {
      let timeout = {
        triggerTimestamp: this.#fakeTimestamp + delay,
        closure: argsClosure
      };
      this.#fakePendingTimeouts.set(handle, timeout);
    }
    return { [kFakeTimerHandle]: handle };
  }
  clearTimeout(handle) {
    if (typeof handle == "number")
      return clearTimeout(handle);
    this.#fakePendingTimeouts.delete(handle[kFakeTimerHandle]);
  }
  queueMicrotask(closure) {
    if (this.#fakeTimestamp === void 0)
      return queueMicrotask(closure);
    let result = closure();
    result instanceof Promise && (this.#fakeRunningTasks.add(result), result.finally(() => this.#fakeRunningTasks.delete(result)));
  }
  // Fake Timers Control API
  #runPendingTimeouts() {
    if (this.#fakeTimestamp !== void 0)
      for (let [handle, timeout] of this.#fakePendingTimeouts)
        timeout.triggerTimestamp <= this.#fakeTimestamp && (this.#fakePendingTimeouts.delete(handle), this.queueMicrotask(timeout.closure));
  }
  enableFakeTimers(timestamp) {
    this.#fakeTimestamp = timestamp, this.#runPendingTimeouts();
  }
  disableFakeTimers() {
    this.#fakeTimestamp = void 0, this.#fakePendingTimeouts.clear();
  }
  advanceFakeTime(delta) {
    assert4(
      this.#fakeTimestamp !== void 0,
      "Expected fake timers to be enabled before `advanceFakeTime()` call"
    ), this.#fakeTimestamp += delta, this.#runPendingTimeouts();
  }
  async waitForFakeTasks() {
    for (; this.#fakeRunningTasks.size > 0; )
      await Promise.all(this.#fakeRunningTasks);
  }
};

// src/workers/shared/types.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
function maybeApply(f, maybeValue) {
  return maybeValue === void 0 ? void 0 : f(maybeValue);
}

// src/workers/shared/object.worker.ts
var MiniflareDurableObject = class extends Router {
  constructor(state, env) {
    super();
    this.state = state;
    this.env = env;
  }
  timers = new Timers();
  // If this Durable Object receives a control op, assume it's being tested.
  // We use this to adjust some limits in tests.
  beingTested = !1;
  #db;
  get db() {
    return this.#db ??= createTypedSql(this.state.storage);
  }
  #name;
  get name() {
    return assert5(
      this.#name !== void 0,
      "Expected `MiniflareDurableObject#fetch()` call before `name` access"
    ), this.#name;
  }
  #blob;
  get blob() {
    if (this.#blob !== void 0)
      return this.#blob;
    let maybeBlobsService = this.env[SharedBindings.MAYBE_SERVICE_BLOBS], stickyBlobs = !!this.env[SharedBindings.MAYBE_JSON_ENABLE_STICKY_BLOBS];
    return assert5(
      maybeBlobsService !== void 0,
      `Expected ${SharedBindings.MAYBE_SERVICE_BLOBS} service binding`
    ), this.#blob = new BlobStore(maybeBlobsService, this.name, stickyBlobs), this.#blob;
  }
  async logWithLevel(level, message) {
    await this.env[SharedBindings.MAYBE_SERVICE_LOOPBACK]?.fetch(
      "http://localhost/core/log",
      {
        method: "POST",
        headers: { [SharedHeaders.LOG_LEVEL]: level.toString() },
        body: message
      }
    );
  }
  async #handleControlOp({
    name,
    args
  }) {
    if (this.beingTested = !0, name === "sqlQuery") {
      assert5(args !== void 0);
      let [query, ...params] = args;
      assert5(typeof query == "string"), assert5(params.every(isTypedValue));
      let results = all(this.db.prepare(query)(...params));
      return Response.json(results);
    } else if (name === "getBlob") {
      assert5(args !== void 0);
      let [id] = args;
      assert5(typeof id == "string");
      let stream = await this.blob.get(id);
      return new Response(stream, { status: stream === null ? 404 : 200 });
    } else {
      let func = this.timers[name];
      assert5(typeof func == "function");
      let result = await func.apply(this.timers, args);
      return Response.json(result ?? null);
    }
  }
  async fetch(req) {
    if (this.env[SharedBindings.MAYBE_JSON_ENABLE_CONTROL_ENDPOINTS] === !0) {
      let controlOp = req?.cf?.miniflare?.controlOp;
      if (controlOp !== void 0)
        return this.#handleControlOp(controlOp);
    }
    let name = req.cf?.miniflare?.name;
    assert5(name !== void 0, "Expected `cf.miniflare.name`"), this.#name = name;
    try {
      return await super.fetch(req);
    } catch (e) {
      let error = reduceError(e), fallback = error.stack ?? error.message, loopbackService = this.env[SharedBindings.MAYBE_SERVICE_LOOPBACK];
      return loopbackService !== void 0 ? loopbackService.fetch("http://localhost/core/error", {
        method: "POST",
        body: JSON.stringify(error)
      }).catch(() => {
        console.error(fallback);
      }) : console.error(fallback), new Response(fallback, { status: 500 });
    } finally {
      req.body !== null && !req.bodyUsed && await req.body.pipeTo(new WritableStream());
    }
  }
};

// src/workers/shared/range.ts
var rangePrefixRegexp = /^ *bytes *=/i, rangeRegexp = /^ *(?<start>\d+)? *- *(?<end>\d+)? *$/;
function parseRanges(rangeHeader, length) {
  let prefixMatch = rangePrefixRegexp.exec(rangeHeader);
  if (prefixMatch === null)
    return;
  if (rangeHeader = rangeHeader.substring(prefixMatch[0].length), rangeHeader.trimStart() === "")
    return [];
  let ranges = rangeHeader.split(","), result = [];
  for (let range of ranges) {
    let match = rangeRegexp.exec(range);
    if (match === null)
      return;
    let { start, end } = match.groups;
    if (start !== void 0 && end !== void 0) {
      let rangeStart = parseInt(start), rangeEnd = parseInt(end);
      if (rangeStart > rangeEnd || rangeStart >= length)
        return;
      rangeEnd >= length && (rangeEnd = length - 1), result.push({ start: rangeStart, end: rangeEnd });
    } else if (start !== void 0 && end === void 0) {
      let rangeStart = parseInt(start);
      if (rangeStart >= length)
        return;
      result.push({ start: rangeStart, end: length - 1 });
    } else if (start === void 0 && end !== void 0) {
      let suffix = parseInt(end);
      if (suffix >= length)
        return [];
      if (suffix === 0)
        continue;
      result.push({ start: length - suffix, end: length - 1 });
    } else
      return;
  }
  return result;
}

// src/workers/shared/sync.ts
import assert6 from "node-internal:internal_assert";
var DeferredPromise = class extends Promise {
  resolve;
  reject;
  constructor(executor = () => {
  }) {
    let promiseResolve, promiseReject;
    super((resolve, reject) => (promiseResolve = resolve, promiseReject = reject, executor(resolve, reject))), this.resolve = promiseResolve, this.reject = promiseReject;
  }
}, Mutex = class {
  locked = !1;
  resolveQueue = [];
  drainQueue = [];
  lock() {
    if (!this.locked) {
      this.locked = !0;
      return;
    }
    return new Promise((resolve) => this.resolveQueue.push(resolve));
  }
  unlock() {
    if (assert6(this.locked), this.resolveQueue.length > 0)
      this.resolveQueue.shift()?.();
    else {
      this.locked = !1;
      let resolve;
      for (; (resolve = this.drainQueue.shift()) !== void 0; )
        resolve();
    }
  }
  get hasWaiting() {
    return this.resolveQueue.length > 0;
  }
  async runWith(closure) {
    let acquireAwaitable = this.lock();
    acquireAwaitable instanceof Promise && await acquireAwaitable;
    try {
      let awaitable = closure();
      return awaitable instanceof Promise ? await awaitable : awaitable;
    } finally {
      this.unlock();
    }
  }
  async drained() {
    if (!(this.resolveQueue.length === 0 && !this.locked))
      return new Promise((resolve) => this.drainQueue.push(resolve));
  }
}, WaitGroup = class {
  counter = 0;
  resolveQueue = [];
  add() {
    this.counter++;
  }
  done() {
    if (assert6(this.counter > 0), this.counter--, this.counter === 0) {
      let resolve;
      for (; (resolve = this.resolveQueue.shift()) !== void 0; )
        resolve();
    }
  }
  wait() {
    return this.counter === 0 ? Promise.resolve() : new Promise((resolve) => this.resolveQueue.push(resolve));
  }
};
export {
  BlobStore,
  DELETE,
  DeferredPromise,
  GET,
  HEAD,
  HttpError,
  KeyValueStorage,
  LogLevel,
  MiniflareDurableObject,
  Mutex,
  PATCH,
  POST,
  PURGE,
  PUT,
  Router,
  SharedBindings,
  SharedHeaders,
  Timers,
  WaitGroup,
  all,
  base64Decode,
  base64Encode,
  drain,
  get,
  maybeApply,
  parseRanges,
  readPrefix,
  reduceError,
  testRegExps,
  viewToBuffer
};
/*! Path sanitisation regexps adapted from node-sanitize-filename:
 * https://github.com/parshap/node-sanitize-filename/blob/209c39b914c8eb48ee27bcbde64b2c7822fdf3de/index.js#L4-L37
 *
 * Licensed under the ISC license:
 *
 * Copyright Parsha Pourkhomami <parshap@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the
 * above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
 * DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
 * ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
//# sourceMappingURL=index.worker.js.map
//# sourceURL=file:///C:/Users/joshr/AppData/Local/Temp/bunx-3240478352-selflare@latest/node_modules/selflare/dist/workers/shared/index.worker.js  miniflare:zod   // src/workers/shared/zod.worker.ts
import { Buffer } from "node-internal:internal_buffer";

// ../../node_modules/.pnpm/zod@3.22.3/node_modules/zod/lib/index.mjs
var util;
(function(util2) {
  util2.assertEqual = (val) => val;
  function assertIs(_arg) {
  }
  util2.assertIs = assertIs;
  function assertNever(_x) {
    throw new Error();
  }
  util2.assertNever = assertNever, util2.arrayToEnum = (items) => {
    let obj = {};
    for (let item of items)
      obj[item] = item;
    return obj;
  }, util2.getValidEnumValues = (obj) => {
    let validKeys = util2.objectKeys(obj).filter((k) => typeof obj[obj[k]] != "number"), filtered = {};
    for (let k of validKeys)
      filtered[k] = obj[k];
    return util2.objectValues(filtered);
  }, util2.objectValues = (obj) => util2.objectKeys(obj).map(function(e) {
    return obj[e];
  }), util2.objectKeys = typeof Object.keys == "function" ? (obj) => Object.keys(obj) : (object) => {
    let keys = [];
    for (let key in object)
      Object.prototype.hasOwnProperty.call(object, key) && keys.push(key);
    return keys;
  }, util2.find = (arr, checker) => {
    for (let item of arr)
      if (checker(item))
        return item;
  }, util2.isInteger = typeof Number.isInteger == "function" ? (val) => Number.isInteger(val) : (val) => typeof val == "number" && isFinite(val) && Math.floor(val) === val;
  function joinValues(array, separator = " | ") {
    return array.map((val) => typeof val == "string" ? `'${val}'` : val).join(separator);
  }
  util2.joinValues = joinValues, util2.jsonStringifyReplacer = (_, value) => typeof value == "bigint" ? value.toString() : value;
})(util || (util = {}));
var objectUtil;
(function(objectUtil2) {
  objectUtil2.mergeShapes = (first, second) => ({
    ...first,
    ...second
    // second overwrites first
  });
})(objectUtil || (objectUtil = {}));
var ZodParsedType = util.arrayToEnum([
  "string",
  "nan",
  "number",
  "integer",
  "float",
  "boolean",
  "date",
  "bigint",
  "symbol",
  "function",
  "undefined",
  "null",
  "array",
  "object",
  "unknown",
  "promise",
  "void",
  "never",
  "map",
  "set"
]), getParsedType = (data) => {
  switch (typeof data) {
    case "undefined":
      return ZodParsedType.undefined;
    case "string":
      return ZodParsedType.string;
    case "number":
      return isNaN(data) ? ZodParsedType.nan : ZodParsedType.number;
    case "boolean":
      return ZodParsedType.boolean;
    case "function":
      return ZodParsedType.function;
    case "bigint":
      return ZodParsedType.bigint;
    case "symbol":
      return ZodParsedType.symbol;
    case "object":
      return Array.isArray(data) ? ZodParsedType.array : data === null ? ZodParsedType.null : data.then && typeof data.then == "function" && data.catch && typeof data.catch == "function" ? ZodParsedType.promise : typeof Map < "u" && data instanceof Map ? ZodParsedType.map : typeof Set < "u" && data instanceof Set ? ZodParsedType.set : typeof Date < "u" && data instanceof Date ? ZodParsedType.date : ZodParsedType.object;
    default:
      return ZodParsedType.unknown;
  }
}, ZodIssueCode = util.arrayToEnum([
  "invalid_type",
  "invalid_literal",
  "custom",
  "invalid_union",
  "invalid_union_discriminator",
  "invalid_enum_value",
  "unrecognized_keys",
  "invalid_arguments",
  "invalid_return_type",
  "invalid_date",
  "invalid_string",
  "too_small",
  "too_big",
  "invalid_intersection_types",
  "not_multiple_of",
  "not_finite"
]), quotelessJson = (obj) => JSON.stringify(obj, null, 2).replace(/"([^"]+)":/g, "$1:"), ZodError = class extends Error {
  constructor(issues) {
    super(), this.issues = [], this.addIssue = (sub) => {
      this.issues = [...this.issues, sub];
    }, this.addIssues = (subs = []) => {
      this.issues = [...this.issues, ...subs];
    };
    let actualProto = new.target.prototype;
    Object.setPrototypeOf ? Object.setPrototypeOf(this, actualProto) : this.__proto__ = actualProto, this.name = "ZodError", this.issues = issues;
  }
  get errors() {
    return this.issues;
  }
  format(_mapper) {
    let mapper = _mapper || function(issue) {
      return issue.message;
    }, fieldErrors = { _errors: [] }, processError = (error) => {
      for (let issue of error.issues)
        if (issue.code === "invalid_union")
          issue.unionErrors.map(processError);
        else if (issue.code === "invalid_return_type")
          processError(issue.returnTypeError);
        else if (issue.code === "invalid_arguments")
          processError(issue.argumentsError);
        else if (issue.path.length === 0)
          fieldErrors._errors.push(mapper(issue));
        else {
          let curr = fieldErrors, i = 0;
          for (; i < issue.path.length; ) {
            let el = issue.path[i];
            i === issue.path.length - 1 ? (curr[el] = curr[el] || { _errors: [] }, curr[el]._errors.push(mapper(issue))) : curr[el] = curr[el] || { _errors: [] }, curr = curr[el], i++;
          }
        }
    };
    return processError(this), fieldErrors;
  }
  toString() {
    return this.message;
  }
  get message() {
    return JSON.stringify(this.issues, util.jsonStringifyReplacer, 2);
  }
  get isEmpty() {
    return this.issues.length === 0;
  }
  flatten(mapper = (issue) => issue.message) {
    let fieldErrors = {}, formErrors = [];
    for (let sub of this.issues)
      sub.path.length > 0 ? (fieldErrors[sub.path[0]] = fieldErrors[sub.path[0]] || [], fieldErrors[sub.path[0]].push(mapper(sub))) : formErrors.push(mapper(sub));
    return { formErrors, fieldErrors };
  }
  get formErrors() {
    return this.flatten();
  }
};
ZodError.create = (issues) => new ZodError(issues);
var errorMap = (issue, _ctx) => {
  let message;
  switch (issue.code) {
    case ZodIssueCode.invalid_type:
      issue.received === ZodParsedType.undefined ? message = "Required" : message = `Expected ${issue.expected}, received ${issue.received}`;
      break;
    case ZodIssueCode.invalid_literal:
      message = `Invalid literal value, expected ${JSON.stringify(issue.expected, util.jsonStringifyReplacer)}`;
      break;
    case ZodIssueCode.unrecognized_keys:
      message = `Unrecognized key(s) in object: ${util.joinValues(issue.keys, ", ")}`;
      break;
    case ZodIssueCode.invalid_union:
      message = "Invalid input";
      break;
    case ZodIssueCode.invalid_union_discriminator:
      message = `Invalid discriminator value. Expected ${util.joinValues(issue.options)}`;
      break;
    case ZodIssueCode.invalid_enum_value:
      message = `Invalid enum value. Expected ${util.joinValues(issue.options)}, received '${issue.received}'`;
      break;
    case ZodIssueCode.invalid_arguments:
      message = "Invalid function arguments";
      break;
    case ZodIssueCode.invalid_return_type:
      message = "Invalid function return type";
      break;
    case ZodIssueCode.invalid_date:
      message = "Invalid date";
      break;
    case ZodIssueCode.invalid_string:
      typeof issue.validation == "object" ? "includes" in issue.validation ? (message = `Invalid input: must include "${issue.validation.includes}"`, typeof issue.validation.position == "number" && (message = `${message} at one or more positions greater than or equal to ${issue.validation.position}`)) : "startsWith" in issue.validation ? message = `Invalid input: must start with "${issue.validation.startsWith}"` : "endsWith" in issue.validation ? message = `Invalid input: must end with "${issue.validation.endsWith}"` : util.assertNever(issue.validation) : issue.validation !== "regex" ? message = `Invalid ${issue.validation}` : message = "Invalid";
      break;
    case ZodIssueCode.too_small:
      issue.type === "array" ? message = `Array must contain ${issue.exact ? "exactly" : issue.inclusive ? "at least" : "more than"} ${issue.minimum} element(s)` : issue.type === "string" ? message = `String must contain ${issue.exact ? "exactly" : issue.inclusive ? "at least" : "over"} ${issue.minimum} character(s)` : issue.type === "number" ? message = `Number must be ${issue.exact ? "exactly equal to " : issue.inclusive ? "greater than or equal to " : "greater than "}${issue.minimum}` : issue.type === "date" ? message = `Date must be ${issue.exact ? "exactly equal to " : issue.inclusive ? "greater than or equal to " : "greater than "}${new Date(Number(issue.minimum))}` : message = "Invalid input";
      break;
    case ZodIssueCode.too_big:
      issue.type === "array" ? message = `Array must contain ${issue.exact ? "exactly" : issue.inclusive ? "at most" : "less than"} ${issue.maximum} element(s)` : issue.type === "string" ? message = `String must contain ${issue.exact ? "exactly" : issue.inclusive ? "at most" : "under"} ${issue.maximum} character(s)` : issue.type === "number" ? message = `Number must be ${issue.exact ? "exactly" : issue.inclusive ? "less than or equal to" : "less than"} ${issue.maximum}` : issue.type === "bigint" ? message = `BigInt must be ${issue.exact ? "exactly" : issue.inclusive ? "less than or equal to" : "less than"} ${issue.maximum}` : issue.type === "date" ? message = `Date must be ${issue.exact ? "exactly" : issue.inclusive ? "smaller than or equal to" : "smaller than"} ${new Date(Number(issue.maximum))}` : message = "Invalid input";
      break;
    case ZodIssueCode.custom:
      message = "Invalid input";
      break;
    case ZodIssueCode.invalid_intersection_types:
      message = "Intersection results could not be merged";
      break;
    case ZodIssueCode.not_multiple_of:
      message = `Number must be a multiple of ${issue.multipleOf}`;
      break;
    case ZodIssueCode.not_finite:
      message = "Number must be finite";
      break;
    default:
      message = _ctx.defaultError, util.assertNever(issue);
  }
  return { message };
}, overrideErrorMap = errorMap;
function setErrorMap(map) {
  overrideErrorMap = map;
}
function getErrorMap() {
  return overrideErrorMap;
}
var makeIssue = (params) => {
  let { data, path, errorMaps, issueData } = params, fullPath = [...path, ...issueData.path || []], fullIssue = {
    ...issueData,
    path: fullPath
  }, errorMessage = "", maps = errorMaps.filter((m) => !!m).slice().reverse();
  for (let map of maps)
    errorMessage = map(fullIssue, { data, defaultError: errorMessage }).message;
  return {
    ...issueData,
    path: fullPath,
    message: issueData.message || errorMessage
  };
}, EMPTY_PATH = [];
function addIssueToContext(ctx, issueData) {
  let issue = makeIssue({
    issueData,
    data: ctx.data,
    path: ctx.path,
    errorMaps: [
      ctx.common.contextualErrorMap,
      ctx.schemaErrorMap,
      getErrorMap(),
      errorMap
      // then global default map
    ].filter((x) => !!x)
  });
  ctx.common.issues.push(issue);
}
var ParseStatus = class {
  constructor() {
    this.value = "valid";
  }
  dirty() {
    this.value === "valid" && (this.value = "dirty");
  }
  abort() {
    this.value !== "aborted" && (this.value = "aborted");
  }
  static mergeArray(status, results) {
    let arrayValue = [];
    for (let s of results) {
      if (s.status === "aborted")
        return INVALID;
      s.status === "dirty" && status.dirty(), arrayValue.push(s.value);
    }
    return { status: status.value, value: arrayValue };
  }
  static async mergeObjectAsync(status, pairs) {
    let syncPairs = [];
    for (let pair of pairs)
      syncPairs.push({
        key: await pair.key,
        value: await pair.value
      });
    return ParseStatus.mergeObjectSync(status, syncPairs);
  }
  static mergeObjectSync(status, pairs) {
    let finalObject = {};
    for (let pair of pairs) {
      let { key, value } = pair;
      if (key.status === "aborted" || value.status === "aborted")
        return INVALID;
      key.status === "dirty" && status.dirty(), value.status === "dirty" && status.dirty(), key.value !== "__proto__" && (typeof value.value < "u" || pair.alwaysSet) && (finalObject[key.value] = value.value);
    }
    return { status: status.value, value: finalObject };
  }
}, INVALID = Object.freeze({
  status: "aborted"
}), DIRTY = (value) => ({ status: "dirty", value }), OK = (value) => ({ status: "valid", value }), isAborted = (x) => x.status === "aborted", isDirty = (x) => x.status === "dirty", isValid = (x) => x.status === "valid", isAsync = (x) => typeof Promise < "u" && x instanceof Promise, errorUtil;
(function(errorUtil2) {
  errorUtil2.errToObj = (message) => typeof message == "string" ? { message } : message || {}, errorUtil2.toString = (message) => typeof message == "string" ? message : message?.message;
})(errorUtil || (errorUtil = {}));
var ParseInputLazyPath = class {
  constructor(parent, value, path, key) {
    this._cachedPath = [], this.parent = parent, this.data = value, this._path = path, this._key = key;
  }
  get path() {
    return this._cachedPath.length || (this._key instanceof Array ? this._cachedPath.push(...this._path, ...this._key) : this._cachedPath.push(...this._path, this._key)), this._cachedPath;
  }
}, handleResult = (ctx, result) => {
  if (isValid(result))
    return { success: !0, data: result.value };
  if (!ctx.common.issues.length)
    throw new Error("Validation failed but no issues detected.");
  return {
    success: !1,
    get error() {
      if (this._error)
        return this._error;
      let error = new ZodError(ctx.common.issues);
      return this._error = error, this._error;
    }
  };
};
function processCreateParams(params) {
  if (!params)
    return {};
  let { errorMap: errorMap2, invalid_type_error, required_error, description } = params;
  if (errorMap2 && (invalid_type_error || required_error))
    throw new Error(`Can't use "invalid_type_error" or "required_error" in conjunction with custom error map.`);
  return errorMap2 ? { errorMap: errorMap2, description } : { errorMap: (iss, ctx) => iss.code !== "invalid_type" ? { message: ctx.defaultError } : typeof ctx.data > "u" ? { message: required_error ?? ctx.defaultError } : { message: invalid_type_error ?? ctx.defaultError }, description };
}
var ZodType = class {
  constructor(def) {
    this.spa = this.safeParseAsync, this._def = def, this.parse = this.parse.bind(this), this.safeParse = this.safeParse.bind(this), this.parseAsync = this.parseAsync.bind(this), this.safeParseAsync = this.safeParseAsync.bind(this), this.spa = this.spa.bind(this), this.refine = this.refine.bind(this), this.refinement = this.refinement.bind(this), this.superRefine = this.superRefine.bind(this), this.optional = this.optional.bind(this), this.nullable = this.nullable.bind(this), this.nullish = this.nullish.bind(this), this.array = this.array.bind(this), this.promise = this.promise.bind(this), this.or = this.or.bind(this), this.and = this.and.bind(this), this.transform = this.transform.bind(this), this.brand = this.brand.bind(this), this.default = this.default.bind(this), this.catch = this.catch.bind(this), this.describe = this.describe.bind(this), this.pipe = this.pipe.bind(this), this.readonly = this.readonly.bind(this), this.isNullable = this.isNullable.bind(this), this.isOptional = this.isOptional.bind(this);
  }
  get description() {
    return this._def.description;
  }
  _getType(input) {
    return getParsedType(input.data);
  }
  _getOrReturnCtx(input, ctx) {
    return ctx || {
      common: input.parent.common,
      data: input.data,
      parsedType: getParsedType(input.data),
      schemaErrorMap: this._def.errorMap,
      path: input.path,
      parent: input.parent
    };
  }
  _processInputParams(input) {
    return {
      status: new ParseStatus(),
      ctx: {
        common: input.parent.common,
        data: input.data,
        parsedType: getParsedType(input.data),
        schemaErrorMap: this._def.errorMap,
        path: input.path,
        parent: input.parent
      }
    };
  }
  _parseSync(input) {
    let result = this._parse(input);
    if (isAsync(result))
      throw new Error("Synchronous parse encountered promise.");
    return result;
  }
  _parseAsync(input) {
    let result = this._parse(input);
    return Promise.resolve(result);
  }
  parse(data, params) {
    let result = this.safeParse(data, params);
    if (result.success)
      return result.data;
    throw result.error;
  }
  safeParse(data, params) {
    var _a;
    let ctx = {
      common: {
        issues: [],
        async: (_a = params?.async) !== null && _a !== void 0 ? _a : !1,
        contextualErrorMap: params?.errorMap
      },
      path: params?.path || [],
      schemaErrorMap: this._def.errorMap,
      parent: null,
      data,
      parsedType: getParsedType(data)
    }, result = this._parseSync({ data, path: ctx.path, parent: ctx });
    return handleResult(ctx, result);
  }
  async parseAsync(data, params) {
    let result = await this.safeParseAsync(data, params);
    if (result.success)
      return result.data;
    throw result.error;
  }
  async safeParseAsync(data, params) {
    let ctx = {
      common: {
        issues: [],
        contextualErrorMap: params?.errorMap,
        async: !0
      },
      path: params?.path || [],
      schemaErrorMap: this._def.errorMap,
      parent: null,
      data,
      parsedType: getParsedType(data)
    }, maybeAsyncResult = this._parse({ data, path: ctx.path, parent: ctx }), result = await (isAsync(maybeAsyncResult) ? maybeAsyncResult : Promise.resolve(maybeAsyncResult));
    return handleResult(ctx, result);
  }
  refine(check, message) {
    let getIssueProperties = (val) => typeof message == "string" || typeof message > "u" ? { message } : typeof message == "function" ? message(val) : message;
    return this._refinement((val, ctx) => {
      let result = check(val), setError = () => ctx.addIssue({
        code: ZodIssueCode.custom,
        ...getIssueProperties(val)
      });
      return typeof Promise < "u" && result instanceof Promise ? result.then((data) => data ? !0 : (setError(), !1)) : result ? !0 : (setError(), !1);
    });
  }
  refinement(check, refinementData) {
    return this._refinement((val, ctx) => check(val) ? !0 : (ctx.addIssue(typeof refinementData == "function" ? refinementData(val, ctx) : refinementData), !1));
  }
  _refinement(refinement) {
    return new ZodEffects({
      schema: this,
      typeName: ZodFirstPartyTypeKind.ZodEffects,
      effect: { type: "refinement", refinement }
    });
  }
  superRefine(refinement) {
    return this._refinement(refinement);
  }
  optional() {
    return ZodOptional.create(this, this._def);
  }
  nullable() {
    return ZodNullable.create(this, this._def);
  }
  nullish() {
    return this.nullable().optional();
  }
  array() {
    return ZodArray.create(this, this._def);
  }
  promise() {
    return ZodPromise.create(this, this._def);
  }
  or(option) {
    return ZodUnion.create([this, option], this._def);
  }
  and(incoming) {
    return ZodIntersection.create(this, incoming, this._def);
  }
  transform(transform) {
    return new ZodEffects({
      ...processCreateParams(this._def),
      schema: this,
      typeName: ZodFirstPartyTypeKind.ZodEffects,
      effect: { type: "transform", transform }
    });
  }
  default(def) {
    let defaultValueFunc = typeof def == "function" ? def : () => def;
    return new ZodDefault({
      ...processCreateParams(this._def),
      innerType: this,
      defaultValue: defaultValueFunc,
      typeName: ZodFirstPartyTypeKind.ZodDefault
    });
  }
  brand() {
    return new ZodBranded({
      typeName: ZodFirstPartyTypeKind.ZodBranded,
      type: this,
      ...processCreateParams(this._def)
    });
  }
  catch(def) {
    let catchValueFunc = typeof def == "function" ? def : () => def;
    return new ZodCatch({
      ...processCreateParams(this._def),
      innerType: this,
      catchValue: catchValueFunc,
      typeName: ZodFirstPartyTypeKind.ZodCatch
    });
  }
  describe(description) {
    let This = this.constructor;
    return new This({
      ...this._def,
      description
    });
  }
  pipe(target) {
    return ZodPipeline.create(this, target);
  }
  readonly() {
    return ZodReadonly.create(this);
  }
  isOptional() {
    return this.safeParse(void 0).success;
  }
  isNullable() {
    return this.safeParse(null).success;
  }
}, cuidRegex = /^c[^\s-]{8,}$/i, cuid2Regex = /^[a-z][a-z0-9]*$/, ulidRegex = /[0-9A-HJKMNP-TV-Z]{26}/, uuidRegex = /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/i, emailRegex = /^(?!\.)(?!.*\.\.)([A-Z0-9_+-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$/i, emojiRegex = /^(\p{Extended_Pictographic}|\p{Emoji_Component})+$/u, ipv4Regex = /^(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))$/, ipv6Regex = /^(([a-f0-9]{1,4}:){7}|::([a-f0-9]{1,4}:){0,6}|([a-f0-9]{1,4}:){1}:([a-f0-9]{1,4}:){0,5}|([a-f0-9]{1,4}:){2}:([a-f0-9]{1,4}:){0,4}|([a-f0-9]{1,4}:){3}:([a-f0-9]{1,4}:){0,3}|([a-f0-9]{1,4}:){4}:([a-f0-9]{1,4}:){0,2}|([a-f0-9]{1,4}:){5}:([a-f0-9]{1,4}:){0,1})([a-f0-9]{1,4}|(((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2}))\.){3}((25[0-5])|(2[0-4][0-9])|(1[0-9]{2})|([0-9]{1,2})))$/, datetimeRegex = (args) => args.precision ? args.offset ? new RegExp(`^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{${args.precision}}(([+-]\\d{2}(:?\\d{2})?)|Z)$`) : new RegExp(`^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{${args.precision}}Z$`) : args.precision === 0 ? args.offset ? new RegExp("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(([+-]\\d{2}(:?\\d{2})?)|Z)$") : new RegExp("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$") : args.offset ? new RegExp("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(([+-]\\d{2}(:?\\d{2})?)|Z)$") : new RegExp("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?Z$");
function isValidIP(ip, version) {
  return !!((version === "v4" || !version) && ipv4Regex.test(ip) || (version === "v6" || !version) && ipv6Regex.test(ip));
}
var ZodString = class extends ZodType {
  constructor() {
    super(...arguments), this._regex = (regex, validation, message) => this.refinement((data) => regex.test(data), {
      validation,
      code: ZodIssueCode.invalid_string,
      ...errorUtil.errToObj(message)
    }), this.nonempty = (message) => this.min(1, errorUtil.errToObj(message)), this.trim = () => new ZodString({
      ...this._def,
      checks: [...this._def.checks, { kind: "trim" }]
    }), this.toLowerCase = () => new ZodString({
      ...this._def,
      checks: [...this._def.checks, { kind: "toLowerCase" }]
    }), this.toUpperCase = () => new ZodString({
      ...this._def,
      checks: [...this._def.checks, { kind: "toUpperCase" }]
    });
  }
  _parse(input) {
    if (this._def.coerce && (input.data = String(input.data)), this._getType(input) !== ZodParsedType.string) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(
        ctx2,
        {
          code: ZodIssueCode.invalid_type,
          expected: ZodParsedType.string,
          received: ctx2.parsedType
        }
        //
      ), INVALID;
    }
    let status = new ParseStatus(), ctx;
    for (let check of this._def.checks)
      if (check.kind === "min")
        input.data.length < check.value && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.too_small,
          minimum: check.value,
          type: "string",
          inclusive: !0,
          exact: !1,
          message: check.message
        }), status.dirty());
      else if (check.kind === "max")
        input.data.length > check.value && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.too_big,
          maximum: check.value,
          type: "string",
          inclusive: !0,
          exact: !1,
          message: check.message
        }), status.dirty());
      else if (check.kind === "length") {
        let tooBig = input.data.length > check.value, tooSmall = input.data.length < check.value;
        (tooBig || tooSmall) && (ctx = this._getOrReturnCtx(input, ctx), tooBig ? addIssueToContext(ctx, {
          code: ZodIssueCode.too_big,
          maximum: check.value,
          type: "string",
          inclusive: !0,
          exact: !0,
          message: check.message
        }) : tooSmall && addIssueToContext(ctx, {
          code: ZodIssueCode.too_small,
          minimum: check.value,
          type: "string",
          inclusive: !0,
          exact: !0,
          message: check.message
        }), status.dirty());
      } else if (check.kind === "email")
        emailRegex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "email",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "emoji")
        emojiRegex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "emoji",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "uuid")
        uuidRegex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "uuid",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "cuid")
        cuidRegex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "cuid",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "cuid2")
        cuid2Regex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "cuid2",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "ulid")
        ulidRegex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "ulid",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty());
      else if (check.kind === "url")
        try {
          new URL(input.data);
        } catch {
          ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
            validation: "url",
            code: ZodIssueCode.invalid_string,
            message: check.message
          }), status.dirty();
        }
      else
        check.kind === "regex" ? (check.regex.lastIndex = 0, check.regex.test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "regex",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty())) : check.kind === "trim" ? input.data = input.data.trim() : check.kind === "includes" ? input.data.includes(check.value, check.position) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.invalid_string,
          validation: { includes: check.value, position: check.position },
          message: check.message
        }), status.dirty()) : check.kind === "toLowerCase" ? input.data = input.data.toLowerCase() : check.kind === "toUpperCase" ? input.data = input.data.toUpperCase() : check.kind === "startsWith" ? input.data.startsWith(check.value) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.invalid_string,
          validation: { startsWith: check.value },
          message: check.message
        }), status.dirty()) : check.kind === "endsWith" ? input.data.endsWith(check.value) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.invalid_string,
          validation: { endsWith: check.value },
          message: check.message
        }), status.dirty()) : check.kind === "datetime" ? datetimeRegex(check).test(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          code: ZodIssueCode.invalid_string,
          validation: "datetime",
          message: check.message
        }), status.dirty()) : check.kind === "ip" ? isValidIP(input.data, check.version) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
          validation: "ip",
          code: ZodIssueCode.invalid_string,
          message: check.message
        }), status.dirty()) : util.assertNever(check);
    return { status: status.value, value: input.data };
  }
  _addCheck(check) {
    return new ZodString({
      ...this._def,
      checks: [...this._def.checks, check]
    });
  }
  email(message) {
    return this._addCheck({ kind: "email", ...errorUtil.errToObj(message) });
  }
  url(message) {
    return this._addCheck({ kind: "url", ...errorUtil.errToObj(message) });
  }
  emoji(message) {
    return this._addCheck({ kind: "emoji", ...errorUtil.errToObj(message) });
  }
  uuid(message) {
    return this._addCheck({ kind: "uuid", ...errorUtil.errToObj(message) });
  }
  cuid(message) {
    return this._addCheck({ kind: "cuid", ...errorUtil.errToObj(message) });
  }
  cuid2(message) {
    return this._addCheck({ kind: "cuid2", ...errorUtil.errToObj(message) });
  }
  ulid(message) {
    return this._addCheck({ kind: "ulid", ...errorUtil.errToObj(message) });
  }
  ip(options) {
    return this._addCheck({ kind: "ip", ...errorUtil.errToObj(options) });
  }
  datetime(options) {
    var _a;
    return typeof options == "string" ? this._addCheck({
      kind: "datetime",
      precision: null,
      offset: !1,
      message: options
    }) : this._addCheck({
      kind: "datetime",
      precision: typeof options?.precision > "u" ? null : options?.precision,
      offset: (_a = options?.offset) !== null && _a !== void 0 ? _a : !1,
      ...errorUtil.errToObj(options?.message)
    });
  }
  regex(regex, message) {
    return this._addCheck({
      kind: "regex",
      regex,
      ...errorUtil.errToObj(message)
    });
  }
  includes(value, options) {
    return this._addCheck({
      kind: "includes",
      value,
      position: options?.position,
      ...errorUtil.errToObj(options?.message)
    });
  }
  startsWith(value, message) {
    return this._addCheck({
      kind: "startsWith",
      value,
      ...errorUtil.errToObj(message)
    });
  }
  endsWith(value, message) {
    return this._addCheck({
      kind: "endsWith",
      value,
      ...errorUtil.errToObj(message)
    });
  }
  min(minLength, message) {
    return this._addCheck({
      kind: "min",
      value: minLength,
      ...errorUtil.errToObj(message)
    });
  }
  max(maxLength, message) {
    return this._addCheck({
      kind: "max",
      value: maxLength,
      ...errorUtil.errToObj(message)
    });
  }
  length(len, message) {
    return this._addCheck({
      kind: "length",
      value: len,
      ...errorUtil.errToObj(message)
    });
  }
  get isDatetime() {
    return !!this._def.checks.find((ch) => ch.kind === "datetime");
  }
  get isEmail() {
    return !!this._def.checks.find((ch) => ch.kind === "email");
  }
  get isURL() {
    return !!this._def.checks.find((ch) => ch.kind === "url");
  }
  get isEmoji() {
    return !!this._def.checks.find((ch) => ch.kind === "emoji");
  }
  get isUUID() {
    return !!this._def.checks.find((ch) => ch.kind === "uuid");
  }
  get isCUID() {
    return !!this._def.checks.find((ch) => ch.kind === "cuid");
  }
  get isCUID2() {
    return !!this._def.checks.find((ch) => ch.kind === "cuid2");
  }
  get isULID() {
    return !!this._def.checks.find((ch) => ch.kind === "ulid");
  }
  get isIP() {
    return !!this._def.checks.find((ch) => ch.kind === "ip");
  }
  get minLength() {
    let min = null;
    for (let ch of this._def.checks)
      ch.kind === "min" && (min === null || ch.value > min) && (min = ch.value);
    return min;
  }
  get maxLength() {
    let max = null;
    for (let ch of this._def.checks)
      ch.kind === "max" && (max === null || ch.value < max) && (max = ch.value);
    return max;
  }
};
ZodString.create = (params) => {
  var _a;
  return new ZodString({
    checks: [],
    typeName: ZodFirstPartyTypeKind.ZodString,
    coerce: (_a = params?.coerce) !== null && _a !== void 0 ? _a : !1,
    ...processCreateParams(params)
  });
};
function floatSafeRemainder(val, step) {
  let valDecCount = (val.toString().split(".")[1] || "").length, stepDecCount = (step.toString().split(".")[1] || "").length, decCount = valDecCount > stepDecCount ? valDecCount : stepDecCount, valInt = parseInt(val.toFixed(decCount).replace(".", "")), stepInt = parseInt(step.toFixed(decCount).replace(".", ""));
  return valInt % stepInt / Math.pow(10, decCount);
}
var ZodNumber = class extends ZodType {
  constructor() {
    super(...arguments), this.min = this.gte, this.max = this.lte, this.step = this.multipleOf;
  }
  _parse(input) {
    if (this._def.coerce && (input.data = Number(input.data)), this._getType(input) !== ZodParsedType.number) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(ctx2, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.number,
        received: ctx2.parsedType
      }), INVALID;
    }
    let ctx, status = new ParseStatus();
    for (let check of this._def.checks)
      check.kind === "int" ? util.isInteger(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: "integer",
        received: "float",
        message: check.message
      }), status.dirty()) : check.kind === "min" ? (check.inclusive ? input.data < check.value : input.data <= check.value) && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_small,
        minimum: check.value,
        type: "number",
        inclusive: check.inclusive,
        exact: !1,
        message: check.message
      }), status.dirty()) : check.kind === "max" ? (check.inclusive ? input.data > check.value : input.data >= check.value) && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_big,
        maximum: check.value,
        type: "number",
        inclusive: check.inclusive,
        exact: !1,
        message: check.message
      }), status.dirty()) : check.kind === "multipleOf" ? floatSafeRemainder(input.data, check.value) !== 0 && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.not_multiple_of,
        multipleOf: check.value,
        message: check.message
      }), status.dirty()) : check.kind === "finite" ? Number.isFinite(input.data) || (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.not_finite,
        message: check.message
      }), status.dirty()) : util.assertNever(check);
    return { status: status.value, value: input.data };
  }
  gte(value, message) {
    return this.setLimit("min", value, !0, errorUtil.toString(message));
  }
  gt(value, message) {
    return this.setLimit("min", value, !1, errorUtil.toString(message));
  }
  lte(value, message) {
    return this.setLimit("max", value, !0, errorUtil.toString(message));
  }
  lt(value, message) {
    return this.setLimit("max", value, !1, errorUtil.toString(message));
  }
  setLimit(kind, value, inclusive, message) {
    return new ZodNumber({
      ...this._def,
      checks: [
        ...this._def.checks,
        {
          kind,
          value,
          inclusive,
          message: errorUtil.toString(message)
        }
      ]
    });
  }
  _addCheck(check) {
    return new ZodNumber({
      ...this._def,
      checks: [...this._def.checks, check]
    });
  }
  int(message) {
    return this._addCheck({
      kind: "int",
      message: errorUtil.toString(message)
    });
  }
  positive(message) {
    return this._addCheck({
      kind: "min",
      value: 0,
      inclusive: !1,
      message: errorUtil.toString(message)
    });
  }
  negative(message) {
    return this._addCheck({
      kind: "max",
      value: 0,
      inclusive: !1,
      message: errorUtil.toString(message)
    });
  }
  nonpositive(message) {
    return this._addCheck({
      kind: "max",
      value: 0,
      inclusive: !0,
      message: errorUtil.toString(message)
    });
  }
  nonnegative(message) {
    return this._addCheck({
      kind: "min",
      value: 0,
      inclusive: !0,
      message: errorUtil.toString(message)
    });
  }
  multipleOf(value, message) {
    return this._addCheck({
      kind: "multipleOf",
      value,
      message: errorUtil.toString(message)
    });
  }
  finite(message) {
    return this._addCheck({
      kind: "finite",
      message: errorUtil.toString(message)
    });
  }
  safe(message) {
    return this._addCheck({
      kind: "min",
      inclusive: !0,
      value: Number.MIN_SAFE_INTEGER,
      message: errorUtil.toString(message)
    })._addCheck({
      kind: "max",
      inclusive: !0,
      value: Number.MAX_SAFE_INTEGER,
      message: errorUtil.toString(message)
    });
  }
  get minValue() {
    let min = null;
    for (let ch of this._def.checks)
      ch.kind === "min" && (min === null || ch.value > min) && (min = ch.value);
    return min;
  }
  get maxValue() {
    let max = null;
    for (let ch of this._def.checks)
      ch.kind === "max" && (max === null || ch.value < max) && (max = ch.value);
    return max;
  }
  get isInt() {
    return !!this._def.checks.find((ch) => ch.kind === "int" || ch.kind === "multipleOf" && util.isInteger(ch.value));
  }
  get isFinite() {
    let max = null, min = null;
    for (let ch of this._def.checks) {
      if (ch.kind === "finite" || ch.kind === "int" || ch.kind === "multipleOf")
        return !0;
      ch.kind === "min" ? (min === null || ch.value > min) && (min = ch.value) : ch.kind === "max" && (max === null || ch.value < max) && (max = ch.value);
    }
    return Number.isFinite(min) && Number.isFinite(max);
  }
};
ZodNumber.create = (params) => new ZodNumber({
  checks: [],
  typeName: ZodFirstPartyTypeKind.ZodNumber,
  coerce: params?.coerce || !1,
  ...processCreateParams(params)
});
var ZodBigInt = class extends ZodType {
  constructor() {
    super(...arguments), this.min = this.gte, this.max = this.lte;
  }
  _parse(input) {
    if (this._def.coerce && (input.data = BigInt(input.data)), this._getType(input) !== ZodParsedType.bigint) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(ctx2, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.bigint,
        received: ctx2.parsedType
      }), INVALID;
    }
    let ctx, status = new ParseStatus();
    for (let check of this._def.checks)
      check.kind === "min" ? (check.inclusive ? input.data < check.value : input.data <= check.value) && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_small,
        type: "bigint",
        minimum: check.value,
        inclusive: check.inclusive,
        message: check.message
      }), status.dirty()) : check.kind === "max" ? (check.inclusive ? input.data > check.value : input.data >= check.value) && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_big,
        type: "bigint",
        maximum: check.value,
        inclusive: check.inclusive,
        message: check.message
      }), status.dirty()) : check.kind === "multipleOf" ? input.data % check.value !== BigInt(0) && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.not_multiple_of,
        multipleOf: check.value,
        message: check.message
      }), status.dirty()) : util.assertNever(check);
    return { status: status.value, value: input.data };
  }
  gte(value, message) {
    return this.setLimit("min", value, !0, errorUtil.toString(message));
  }
  gt(value, message) {
    return this.setLimit("min", value, !1, errorUtil.toString(message));
  }
  lte(value, message) {
    return this.setLimit("max", value, !0, errorUtil.toString(message));
  }
  lt(value, message) {
    return this.setLimit("max", value, !1, errorUtil.toString(message));
  }
  setLimit(kind, value, inclusive, message) {
    return new ZodBigInt({
      ...this._def,
      checks: [
        ...this._def.checks,
        {
          kind,
          value,
          inclusive,
          message: errorUtil.toString(message)
        }
      ]
    });
  }
  _addCheck(check) {
    return new ZodBigInt({
      ...this._def,
      checks: [...this._def.checks, check]
    });
  }
  positive(message) {
    return this._addCheck({
      kind: "min",
      value: BigInt(0),
      inclusive: !1,
      message: errorUtil.toString(message)
    });
  }
  negative(message) {
    return this._addCheck({
      kind: "max",
      value: BigInt(0),
      inclusive: !1,
      message: errorUtil.toString(message)
    });
  }
  nonpositive(message) {
    return this._addCheck({
      kind: "max",
      value: BigInt(0),
      inclusive: !0,
      message: errorUtil.toString(message)
    });
  }
  nonnegative(message) {
    return this._addCheck({
      kind: "min",
      value: BigInt(0),
      inclusive: !0,
      message: errorUtil.toString(message)
    });
  }
  multipleOf(value, message) {
    return this._addCheck({
      kind: "multipleOf",
      value,
      message: errorUtil.toString(message)
    });
  }
  get minValue() {
    let min = null;
    for (let ch of this._def.checks)
      ch.kind === "min" && (min === null || ch.value > min) && (min = ch.value);
    return min;
  }
  get maxValue() {
    let max = null;
    for (let ch of this._def.checks)
      ch.kind === "max" && (max === null || ch.value < max) && (max = ch.value);
    return max;
  }
};
ZodBigInt.create = (params) => {
  var _a;
  return new ZodBigInt({
    checks: [],
    typeName: ZodFirstPartyTypeKind.ZodBigInt,
    coerce: (_a = params?.coerce) !== null && _a !== void 0 ? _a : !1,
    ...processCreateParams(params)
  });
};
var ZodBoolean = class extends ZodType {
  _parse(input) {
    if (this._def.coerce && (input.data = Boolean(input.data)), this._getType(input) !== ZodParsedType.boolean) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.boolean,
        received: ctx.parsedType
      }), INVALID;
    }
    return OK(input.data);
  }
};
ZodBoolean.create = (params) => new ZodBoolean({
  typeName: ZodFirstPartyTypeKind.ZodBoolean,
  coerce: params?.coerce || !1,
  ...processCreateParams(params)
});
var ZodDate = class extends ZodType {
  _parse(input) {
    if (this._def.coerce && (input.data = new Date(input.data)), this._getType(input) !== ZodParsedType.date) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(ctx2, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.date,
        received: ctx2.parsedType
      }), INVALID;
    }
    if (isNaN(input.data.getTime())) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(ctx2, {
        code: ZodIssueCode.invalid_date
      }), INVALID;
    }
    let status = new ParseStatus(), ctx;
    for (let check of this._def.checks)
      check.kind === "min" ? input.data.getTime() < check.value && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_small,
        message: check.message,
        inclusive: !0,
        exact: !1,
        minimum: check.value,
        type: "date"
      }), status.dirty()) : check.kind === "max" ? input.data.getTime() > check.value && (ctx = this._getOrReturnCtx(input, ctx), addIssueToContext(ctx, {
        code: ZodIssueCode.too_big,
        message: check.message,
        inclusive: !0,
        exact: !1,
        maximum: check.value,
        type: "date"
      }), status.dirty()) : util.assertNever(check);
    return {
      status: status.value,
      value: new Date(input.data.getTime())
    };
  }
  _addCheck(check) {
    return new ZodDate({
      ...this._def,
      checks: [...this._def.checks, check]
    });
  }
  min(minDate, message) {
    return this._addCheck({
      kind: "min",
      value: minDate.getTime(),
      message: errorUtil.toString(message)
    });
  }
  max(maxDate, message) {
    return this._addCheck({
      kind: "max",
      value: maxDate.getTime(),
      message: errorUtil.toString(message)
    });
  }
  get minDate() {
    let min = null;
    for (let ch of this._def.checks)
      ch.kind === "min" && (min === null || ch.value > min) && (min = ch.value);
    return min != null ? new Date(min) : null;
  }
  get maxDate() {
    let max = null;
    for (let ch of this._def.checks)
      ch.kind === "max" && (max === null || ch.value < max) && (max = ch.value);
    return max != null ? new Date(max) : null;
  }
};
ZodDate.create = (params) => new ZodDate({
  checks: [],
  coerce: params?.coerce || !1,
  typeName: ZodFirstPartyTypeKind.ZodDate,
  ...processCreateParams(params)
});
var ZodSymbol = class extends ZodType {
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.symbol) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.symbol,
        received: ctx.parsedType
      }), INVALID;
    }
    return OK(input.data);
  }
};
ZodSymbol.create = (params) => new ZodSymbol({
  typeName: ZodFirstPartyTypeKind.ZodSymbol,
  ...processCreateParams(params)
});
var ZodUndefined = class extends ZodType {
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.undefined) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.undefined,
        received: ctx.parsedType
      }), INVALID;
    }
    return OK(input.data);
  }
};
ZodUndefined.create = (params) => new ZodUndefined({
  typeName: ZodFirstPartyTypeKind.ZodUndefined,
  ...processCreateParams(params)
});
var ZodNull = class extends ZodType {
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.null) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.null,
        received: ctx.parsedType
      }), INVALID;
    }
    return OK(input.data);
  }
};
ZodNull.create = (params) => new ZodNull({
  typeName: ZodFirstPartyTypeKind.ZodNull,
  ...processCreateParams(params)
});
var ZodAny = class extends ZodType {
  constructor() {
    super(...arguments), this._any = !0;
  }
  _parse(input) {
    return OK(input.data);
  }
};
ZodAny.create = (params) => new ZodAny({
  typeName: ZodFirstPartyTypeKind.ZodAny,
  ...processCreateParams(params)
});
var ZodUnknown = class extends ZodType {
  constructor() {
    super(...arguments), this._unknown = !0;
  }
  _parse(input) {
    return OK(input.data);
  }
};
ZodUnknown.create = (params) => new ZodUnknown({
  typeName: ZodFirstPartyTypeKind.ZodUnknown,
  ...processCreateParams(params)
});
var ZodNever = class extends ZodType {
  _parse(input) {
    let ctx = this._getOrReturnCtx(input);
    return addIssueToContext(ctx, {
      code: ZodIssueCode.invalid_type,
      expected: ZodParsedType.never,
      received: ctx.parsedType
    }), INVALID;
  }
};
ZodNever.create = (params) => new ZodNever({
  typeName: ZodFirstPartyTypeKind.ZodNever,
  ...processCreateParams(params)
});
var ZodVoid = class extends ZodType {
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.undefined) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.void,
        received: ctx.parsedType
      }), INVALID;
    }
    return OK(input.data);
  }
};
ZodVoid.create = (params) => new ZodVoid({
  typeName: ZodFirstPartyTypeKind.ZodVoid,
  ...processCreateParams(params)
});
var ZodArray = class extends ZodType {
  _parse(input) {
    let { ctx, status } = this._processInputParams(input), def = this._def;
    if (ctx.parsedType !== ZodParsedType.array)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.array,
        received: ctx.parsedType
      }), INVALID;
    if (def.exactLength !== null) {
      let tooBig = ctx.data.length > def.exactLength.value, tooSmall = ctx.data.length < def.exactLength.value;
      (tooBig || tooSmall) && (addIssueToContext(ctx, {
        code: tooBig ? ZodIssueCode.too_big : ZodIssueCode.too_small,
        minimum: tooSmall ? def.exactLength.value : void 0,
        maximum: tooBig ? def.exactLength.value : void 0,
        type: "array",
        inclusive: !0,
        exact: !0,
        message: def.exactLength.message
      }), status.dirty());
    }
    if (def.minLength !== null && ctx.data.length < def.minLength.value && (addIssueToContext(ctx, {
      code: ZodIssueCode.too_small,
      minimum: def.minLength.value,
      type: "array",
      inclusive: !0,
      exact: !1,
      message: def.minLength.message
    }), status.dirty()), def.maxLength !== null && ctx.data.length > def.maxLength.value && (addIssueToContext(ctx, {
      code: ZodIssueCode.too_big,
      maximum: def.maxLength.value,
      type: "array",
      inclusive: !0,
      exact: !1,
      message: def.maxLength.message
    }), status.dirty()), ctx.common.async)
      return Promise.all([...ctx.data].map((item, i) => def.type._parseAsync(new ParseInputLazyPath(ctx, item, ctx.path, i)))).then((result2) => ParseStatus.mergeArray(status, result2));
    let result = [...ctx.data].map((item, i) => def.type._parseSync(new ParseInputLazyPath(ctx, item, ctx.path, i)));
    return ParseStatus.mergeArray(status, result);
  }
  get element() {
    return this._def.type;
  }
  min(minLength, message) {
    return new ZodArray({
      ...this._def,
      minLength: { value: minLength, message: errorUtil.toString(message) }
    });
  }
  max(maxLength, message) {
    return new ZodArray({
      ...this._def,
      maxLength: { value: maxLength, message: errorUtil.toString(message) }
    });
  }
  length(len, message) {
    return new ZodArray({
      ...this._def,
      exactLength: { value: len, message: errorUtil.toString(message) }
    });
  }
  nonempty(message) {
    return this.min(1, message);
  }
};
ZodArray.create = (schema, params) => new ZodArray({
  type: schema,
  minLength: null,
  maxLength: null,
  exactLength: null,
  typeName: ZodFirstPartyTypeKind.ZodArray,
  ...processCreateParams(params)
});
function deepPartialify(schema) {
  if (schema instanceof ZodObject) {
    let newShape = {};
    for (let key in schema.shape) {
      let fieldSchema = schema.shape[key];
      newShape[key] = ZodOptional.create(deepPartialify(fieldSchema));
    }
    return new ZodObject({
      ...schema._def,
      shape: () => newShape
    });
  } else
    return schema instanceof ZodArray ? new ZodArray({
      ...schema._def,
      type: deepPartialify(schema.element)
    }) : schema instanceof ZodOptional ? ZodOptional.create(deepPartialify(schema.unwrap())) : schema instanceof ZodNullable ? ZodNullable.create(deepPartialify(schema.unwrap())) : schema instanceof ZodTuple ? ZodTuple.create(schema.items.map((item) => deepPartialify(item))) : schema;
}
var ZodObject = class extends ZodType {
  constructor() {
    super(...arguments), this._cached = null, this.nonstrict = this.passthrough, this.augment = this.extend;
  }
  _getCached() {
    if (this._cached !== null)
      return this._cached;
    let shape = this._def.shape(), keys = util.objectKeys(shape);
    return this._cached = { shape, keys };
  }
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.object) {
      let ctx2 = this._getOrReturnCtx(input);
      return addIssueToContext(ctx2, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.object,
        received: ctx2.parsedType
      }), INVALID;
    }
    let { status, ctx } = this._processInputParams(input), { shape, keys: shapeKeys } = this._getCached(), extraKeys = [];
    if (!(this._def.catchall instanceof ZodNever && this._def.unknownKeys === "strip"))
      for (let key in ctx.data)
        shapeKeys.includes(key) || extraKeys.push(key);
    let pairs = [];
    for (let key of shapeKeys) {
      let keyValidator = shape[key], value = ctx.data[key];
      pairs.push({
        key: { status: "valid", value: key },
        value: keyValidator._parse(new ParseInputLazyPath(ctx, value, ctx.path, key)),
        alwaysSet: key in ctx.data
      });
    }
    if (this._def.catchall instanceof ZodNever) {
      let unknownKeys = this._def.unknownKeys;
      if (unknownKeys === "passthrough")
        for (let key of extraKeys)
          pairs.push({
            key: { status: "valid", value: key },
            value: { status: "valid", value: ctx.data[key] }
          });
      else if (unknownKeys === "strict")
        extraKeys.length > 0 && (addIssueToContext(ctx, {
          code: ZodIssueCode.unrecognized_keys,
          keys: extraKeys
        }), status.dirty());
      else if (unknownKeys !== "strip")
        throw new Error("Internal ZodObject error: invalid unknownKeys value.");
    } else {
      let catchall = this._def.catchall;
      for (let key of extraKeys) {
        let value = ctx.data[key];
        pairs.push({
          key: { status: "valid", value: key },
          value: catchall._parse(
            new ParseInputLazyPath(ctx, value, ctx.path, key)
            //, ctx.child(key), value, getParsedType(value)
          ),
          alwaysSet: key in ctx.data
        });
      }
    }
    return ctx.common.async ? Promise.resolve().then(async () => {
      let syncPairs = [];
      for (let pair of pairs) {
        let key = await pair.key;
        syncPairs.push({
          key,
          value: await pair.value,
          alwaysSet: pair.alwaysSet
        });
      }
      return syncPairs;
    }).then((syncPairs) => ParseStatus.mergeObjectSync(status, syncPairs)) : ParseStatus.mergeObjectSync(status, pairs);
  }
  get shape() {
    return this._def.shape();
  }
  strict(message) {
    return errorUtil.errToObj, new ZodObject({
      ...this._def,
      unknownKeys: "strict",
      ...message !== void 0 ? {
        errorMap: (issue, ctx) => {
          var _a, _b, _c, _d;
          let defaultError = (_c = (_b = (_a = this._def).errorMap) === null || _b === void 0 ? void 0 : _b.call(_a, issue, ctx).message) !== null && _c !== void 0 ? _c : ctx.defaultError;
          return issue.code === "unrecognized_keys" ? {
            message: (_d = errorUtil.errToObj(message).message) !== null && _d !== void 0 ? _d : defaultError
          } : {
            message: defaultError
          };
        }
      } : {}
    });
  }
  strip() {
    return new ZodObject({
      ...this._def,
      unknownKeys: "strip"
    });
  }
  passthrough() {
    return new ZodObject({
      ...this._def,
      unknownKeys: "passthrough"
    });
  }
  // const AugmentFactory =
  //   <Def extends ZodObjectDef>(def: Def) =>
  //   <Augmentation extends ZodRawShape>(
  //     augmentation: Augmentation
  //   ): ZodObject<
  //     extendShape<ReturnType<Def["shape"]>, Augmentation>,
  //     Def["unknownKeys"],
  //     Def["catchall"]
  //   > => {
  //     return new ZodObject({
  //       ...def,
  //       shape: () => ({
  //         ...def.shape(),
  //         ...augmentation,
  //       }),
  //     }) as any;
  //   };
  extend(augmentation) {
    return new ZodObject({
      ...this._def,
      shape: () => ({
        ...this._def.shape(),
        ...augmentation
      })
    });
  }
  /**
   * Prior to zod@1.0.12 there was a bug in the
   * inferred type of merged objects. Please
   * upgrade if you are experiencing issues.
   */
  merge(merging) {
    return new ZodObject({
      unknownKeys: merging._def.unknownKeys,
      catchall: merging._def.catchall,
      shape: () => ({
        ...this._def.shape(),
        ...merging._def.shape()
      }),
      typeName: ZodFirstPartyTypeKind.ZodObject
    });
  }
  // merge<
  //   Incoming extends AnyZodObject,
  //   Augmentation extends Incoming["shape"],
  //   NewOutput extends {
  //     [k in keyof Augmentation | keyof Output]: k extends keyof Augmentation
  //       ? Augmentation[k]["_output"]
  //       : k extends keyof Output
  //       ? Output[k]
  //       : never;
  //   },
  //   NewInput extends {
  //     [k in keyof Augmentation | keyof Input]: k extends keyof Augmentation
  //       ? Augmentation[k]["_input"]
  //       : k extends keyof Input
  //       ? Input[k]
  //       : never;
  //   }
  // >(
  //   merging: Incoming
  // ): ZodObject<
  //   extendShape<T, ReturnType<Incoming["_def"]["shape"]>>,
  //   Incoming["_def"]["unknownKeys"],
  //   Incoming["_def"]["catchall"],
  //   NewOutput,
  //   NewInput
  // > {
  //   const merged: any = new ZodObject({
  //     unknownKeys: merging._def.unknownKeys,
  //     catchall: merging._def.catchall,
  //     shape: () =>
  //       objectUtil.mergeShapes(this._def.shape(), merging._def.shape()),
  //     typeName: ZodFirstPartyTypeKind.ZodObject,
  //   }) as any;
  //   return merged;
  // }
  setKey(key, schema) {
    return this.augment({ [key]: schema });
  }
  // merge<Incoming extends AnyZodObject>(
  //   merging: Incoming
  // ): //ZodObject<T & Incoming["_shape"], UnknownKeys, Catchall> = (merging) => {
  // ZodObject<
  //   extendShape<T, ReturnType<Incoming["_def"]["shape"]>>,
  //   Incoming["_def"]["unknownKeys"],
  //   Incoming["_def"]["catchall"]
  // > {
  //   // const mergedShape = objectUtil.mergeShapes(
  //   //   this._def.shape(),
  //   //   merging._def.shape()
  //   // );
  //   const merged: any = new ZodObject({
  //     unknownKeys: merging._def.unknownKeys,
  //     catchall: merging._def.catchall,
  //     shape: () =>
  //       objectUtil.mergeShapes(this._def.shape(), merging._def.shape()),
  //     typeName: ZodFirstPartyTypeKind.ZodObject,
  //   }) as any;
  //   return merged;
  // }
  catchall(index) {
    return new ZodObject({
      ...this._def,
      catchall: index
    });
  }
  pick(mask) {
    let shape = {};
    return util.objectKeys(mask).forEach((key) => {
      mask[key] && this.shape[key] && (shape[key] = this.shape[key]);
    }), new ZodObject({
      ...this._def,
      shape: () => shape
    });
  }
  omit(mask) {
    let shape = {};
    return util.objectKeys(this.shape).forEach((key) => {
      mask[key] || (shape[key] = this.shape[key]);
    }), new ZodObject({
      ...this._def,
      shape: () => shape
    });
  }
  /**
   * @deprecated
   */
  deepPartial() {
    return deepPartialify(this);
  }
  partial(mask) {
    let newShape = {};
    return util.objectKeys(this.shape).forEach((key) => {
      let fieldSchema = this.shape[key];
      mask && !mask[key] ? newShape[key] = fieldSchema : newShape[key] = fieldSchema.optional();
    }), new ZodObject({
      ...this._def,
      shape: () => newShape
    });
  }
  required(mask) {
    let newShape = {};
    return util.objectKeys(this.shape).forEach((key) => {
      if (mask && !mask[key])
        newShape[key] = this.shape[key];
      else {
        let newField = this.shape[key];
        for (; newField instanceof ZodOptional; )
          newField = newField._def.innerType;
        newShape[key] = newField;
      }
    }), new ZodObject({
      ...this._def,
      shape: () => newShape
    });
  }
  keyof() {
    return createZodEnum(util.objectKeys(this.shape));
  }
};
ZodObject.create = (shape, params) => new ZodObject({
  shape: () => shape,
  unknownKeys: "strip",
  catchall: ZodNever.create(),
  typeName: ZodFirstPartyTypeKind.ZodObject,
  ...processCreateParams(params)
});
ZodObject.strictCreate = (shape, params) => new ZodObject({
  shape: () => shape,
  unknownKeys: "strict",
  catchall: ZodNever.create(),
  typeName: ZodFirstPartyTypeKind.ZodObject,
  ...processCreateParams(params)
});
ZodObject.lazycreate = (shape, params) => new ZodObject({
  shape,
  unknownKeys: "strip",
  catchall: ZodNever.create(),
  typeName: ZodFirstPartyTypeKind.ZodObject,
  ...processCreateParams(params)
});
var ZodUnion = class extends ZodType {
  _parse(input) {
    let { ctx } = this._processInputParams(input), options = this._def.options;
    function handleResults(results) {
      for (let result of results)
        if (result.result.status === "valid")
          return result.result;
      for (let result of results)
        if (result.result.status === "dirty")
          return ctx.common.issues.push(...result.ctx.common.issues), result.result;
      let unionErrors = results.map((result) => new ZodError(result.ctx.common.issues));
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_union,
        unionErrors
      }), INVALID;
    }
    if (ctx.common.async)
      return Promise.all(options.map(async (option) => {
        let childCtx = {
          ...ctx,
          common: {
            ...ctx.common,
            issues: []
          },
          parent: null
        };
        return {
          result: await option._parseAsync({
            data: ctx.data,
            path: ctx.path,
            parent: childCtx
          }),
          ctx: childCtx
        };
      })).then(handleResults);
    {
      let dirty, issues = [];
      for (let option of options) {
        let childCtx = {
          ...ctx,
          common: {
            ...ctx.common,
            issues: []
          },
          parent: null
        }, result = option._parseSync({
          data: ctx.data,
          path: ctx.path,
          parent: childCtx
        });
        if (result.status === "valid")
          return result;
        result.status === "dirty" && !dirty && (dirty = { result, ctx: childCtx }), childCtx.common.issues.length && issues.push(childCtx.common.issues);
      }
      if (dirty)
        return ctx.common.issues.push(...dirty.ctx.common.issues), dirty.result;
      let unionErrors = issues.map((issues2) => new ZodError(issues2));
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_union,
        unionErrors
      }), INVALID;
    }
  }
  get options() {
    return this._def.options;
  }
};
ZodUnion.create = (types, params) => new ZodUnion({
  options: types,
  typeName: ZodFirstPartyTypeKind.ZodUnion,
  ...processCreateParams(params)
});
var getDiscriminator = (type) => type instanceof ZodLazy ? getDiscriminator(type.schema) : type instanceof ZodEffects ? getDiscriminator(type.innerType()) : type instanceof ZodLiteral ? [type.value] : type instanceof ZodEnum ? type.options : type instanceof ZodNativeEnum ? Object.keys(type.enum) : type instanceof ZodDefault ? getDiscriminator(type._def.innerType) : type instanceof ZodUndefined ? [void 0] : type instanceof ZodNull ? [null] : null, ZodDiscriminatedUnion = class extends ZodType {
  _parse(input) {
    let { ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.object)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.object,
        received: ctx.parsedType
      }), INVALID;
    let discriminator = this.discriminator, discriminatorValue = ctx.data[discriminator], option = this.optionsMap.get(discriminatorValue);
    return option ? ctx.common.async ? option._parseAsync({
      data: ctx.data,
      path: ctx.path,
      parent: ctx
    }) : option._parseSync({
      data: ctx.data,
      path: ctx.path,
      parent: ctx
    }) : (addIssueToContext(ctx, {
      code: ZodIssueCode.invalid_union_discriminator,
      options: Array.from(this.optionsMap.keys()),
      path: [discriminator]
    }), INVALID);
  }
  get discriminator() {
    return this._def.discriminator;
  }
  get options() {
    return this._def.options;
  }
  get optionsMap() {
    return this._def.optionsMap;
  }
  /**
   * The constructor of the discriminated union schema. Its behaviour is very similar to that of the normal z.union() constructor.
   * However, it only allows a union of objects, all of which need to share a discriminator property. This property must
   * have a different value for each object in the union.
   * @param discriminator the name of the discriminator property
   * @param types an array of object schemas
   * @param params
   */
  static create(discriminator, options, params) {
    let optionsMap = /* @__PURE__ */ new Map();
    for (let type of options) {
      let discriminatorValues = getDiscriminator(type.shape[discriminator]);
      if (!discriminatorValues)
        throw new Error(`A discriminator value for key \`${discriminator}\` could not be extracted from all schema options`);
      for (let value of discriminatorValues) {
        if (optionsMap.has(value))
          throw new Error(`Discriminator property ${String(discriminator)} has duplicate value ${String(value)}`);
        optionsMap.set(value, type);
      }
    }
    return new ZodDiscriminatedUnion({
      typeName: ZodFirstPartyTypeKind.ZodDiscriminatedUnion,
      discriminator,
      options,
      optionsMap,
      ...processCreateParams(params)
    });
  }
};
function mergeValues(a, b) {
  let aType = getParsedType(a), bType = getParsedType(b);
  if (a === b)
    return { valid: !0, data: a };
  if (aType === ZodParsedType.object && bType === ZodParsedType.object) {
    let bKeys = util.objectKeys(b), sharedKeys = util.objectKeys(a).filter((key) => bKeys.indexOf(key) !== -1), newObj = { ...a, ...b };
    for (let key of sharedKeys) {
      let sharedValue = mergeValues(a[key], b[key]);
      if (!sharedValue.valid)
        return { valid: !1 };
      newObj[key] = sharedValue.data;
    }
    return { valid: !0, data: newObj };
  } else if (aType === ZodParsedType.array && bType === ZodParsedType.array) {
    if (a.length !== b.length)
      return { valid: !1 };
    let newArray = [];
    for (let index = 0; index < a.length; index++) {
      let itemA = a[index], itemB = b[index], sharedValue = mergeValues(itemA, itemB);
      if (!sharedValue.valid)
        return { valid: !1 };
      newArray.push(sharedValue.data);
    }
    return { valid: !0, data: newArray };
  } else
    return aType === ZodParsedType.date && bType === ZodParsedType.date && +a == +b ? { valid: !0, data: a } : { valid: !1 };
}
var ZodIntersection = class extends ZodType {
  _parse(input) {
    let { status, ctx } = this._processInputParams(input), handleParsed = (parsedLeft, parsedRight) => {
      if (isAborted(parsedLeft) || isAborted(parsedRight))
        return INVALID;
      let merged = mergeValues(parsedLeft.value, parsedRight.value);
      return merged.valid ? ((isDirty(parsedLeft) || isDirty(parsedRight)) && status.dirty(), { status: status.value, value: merged.data }) : (addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_intersection_types
      }), INVALID);
    };
    return ctx.common.async ? Promise.all([
      this._def.left._parseAsync({
        data: ctx.data,
        path: ctx.path,
        parent: ctx
      }),
      this._def.right._parseAsync({
        data: ctx.data,
        path: ctx.path,
        parent: ctx
      })
    ]).then(([left, right]) => handleParsed(left, right)) : handleParsed(this._def.left._parseSync({
      data: ctx.data,
      path: ctx.path,
      parent: ctx
    }), this._def.right._parseSync({
      data: ctx.data,
      path: ctx.path,
      parent: ctx
    }));
  }
};
ZodIntersection.create = (left, right, params) => new ZodIntersection({
  left,
  right,
  typeName: ZodFirstPartyTypeKind.ZodIntersection,
  ...processCreateParams(params)
});
var ZodTuple = class extends ZodType {
  _parse(input) {
    let { status, ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.array)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.array,
        received: ctx.parsedType
      }), INVALID;
    if (ctx.data.length < this._def.items.length)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.too_small,
        minimum: this._def.items.length,
        inclusive: !0,
        exact: !1,
        type: "array"
      }), INVALID;
    !this._def.rest && ctx.data.length > this._def.items.length && (addIssueToContext(ctx, {
      code: ZodIssueCode.too_big,
      maximum: this._def.items.length,
      inclusive: !0,
      exact: !1,
      type: "array"
    }), status.dirty());
    let items = [...ctx.data].map((item, itemIndex) => {
      let schema = this._def.items[itemIndex] || this._def.rest;
      return schema ? schema._parse(new ParseInputLazyPath(ctx, item, ctx.path, itemIndex)) : null;
    }).filter((x) => !!x);
    return ctx.common.async ? Promise.all(items).then((results) => ParseStatus.mergeArray(status, results)) : ParseStatus.mergeArray(status, items);
  }
  get items() {
    return this._def.items;
  }
  rest(rest) {
    return new ZodTuple({
      ...this._def,
      rest
    });
  }
};
ZodTuple.create = (schemas, params) => {
  if (!Array.isArray(schemas))
    throw new Error("You must pass an array of schemas to z.tuple([ ... ])");
  return new ZodTuple({
    items: schemas,
    typeName: ZodFirstPartyTypeKind.ZodTuple,
    rest: null,
    ...processCreateParams(params)
  });
};
var ZodRecord = class extends ZodType {
  get keySchema() {
    return this._def.keyType;
  }
  get valueSchema() {
    return this._def.valueType;
  }
  _parse(input) {
    let { status, ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.object)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.object,
        received: ctx.parsedType
      }), INVALID;
    let pairs = [], keyType = this._def.keyType, valueType = this._def.valueType;
    for (let key in ctx.data)
      pairs.push({
        key: keyType._parse(new ParseInputLazyPath(ctx, key, ctx.path, key)),
        value: valueType._parse(new ParseInputLazyPath(ctx, ctx.data[key], ctx.path, key))
      });
    return ctx.common.async ? ParseStatus.mergeObjectAsync(status, pairs) : ParseStatus.mergeObjectSync(status, pairs);
  }
  get element() {
    return this._def.valueType;
  }
  static create(first, second, third) {
    return second instanceof ZodType ? new ZodRecord({
      keyType: first,
      valueType: second,
      typeName: ZodFirstPartyTypeKind.ZodRecord,
      ...processCreateParams(third)
    }) : new ZodRecord({
      keyType: ZodString.create(),
      valueType: first,
      typeName: ZodFirstPartyTypeKind.ZodRecord,
      ...processCreateParams(second)
    });
  }
}, ZodMap = class extends ZodType {
  get keySchema() {
    return this._def.keyType;
  }
  get valueSchema() {
    return this._def.valueType;
  }
  _parse(input) {
    let { status, ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.map)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.map,
        received: ctx.parsedType
      }), INVALID;
    let keyType = this._def.keyType, valueType = this._def.valueType, pairs = [...ctx.data.entries()].map(([key, value], index) => ({
      key: keyType._parse(new ParseInputLazyPath(ctx, key, ctx.path, [index, "key"])),
      value: valueType._parse(new ParseInputLazyPath(ctx, value, ctx.path, [index, "value"]))
    }));
    if (ctx.common.async) {
      let finalMap = /* @__PURE__ */ new Map();
      return Promise.resolve().then(async () => {
        for (let pair of pairs) {
          let key = await pair.key, value = await pair.value;
          if (key.status === "aborted" || value.status === "aborted")
            return INVALID;
          (key.status === "dirty" || value.status === "dirty") && status.dirty(), finalMap.set(key.value, value.value);
        }
        return { status: status.value, value: finalMap };
      });
    } else {
      let finalMap = /* @__PURE__ */ new Map();
      for (let pair of pairs) {
        let key = pair.key, value = pair.value;
        if (key.status === "aborted" || value.status === "aborted")
          return INVALID;
        (key.status === "dirty" || value.status === "dirty") && status.dirty(), finalMap.set(key.value, value.value);
      }
      return { status: status.value, value: finalMap };
    }
  }
};
ZodMap.create = (keyType, valueType, params) => new ZodMap({
  valueType,
  keyType,
  typeName: ZodFirstPartyTypeKind.ZodMap,
  ...processCreateParams(params)
});
var ZodSet = class extends ZodType {
  _parse(input) {
    let { status, ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.set)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.set,
        received: ctx.parsedType
      }), INVALID;
    let def = this._def;
    def.minSize !== null && ctx.data.size < def.minSize.value && (addIssueToContext(ctx, {
      code: ZodIssueCode.too_small,
      minimum: def.minSize.value,
      type: "set",
      inclusive: !0,
      exact: !1,
      message: def.minSize.message
    }), status.dirty()), def.maxSize !== null && ctx.data.size > def.maxSize.value && (addIssueToContext(ctx, {
      code: ZodIssueCode.too_big,
      maximum: def.maxSize.value,
      type: "set",
      inclusive: !0,
      exact: !1,
      message: def.maxSize.message
    }), status.dirty());
    let valueType = this._def.valueType;
    function finalizeSet(elements2) {
      let parsedSet = /* @__PURE__ */ new Set();
      for (let element of elements2) {
        if (element.status === "aborted")
          return INVALID;
        element.status === "dirty" && status.dirty(), parsedSet.add(element.value);
      }
      return { status: status.value, value: parsedSet };
    }
    let elements = [...ctx.data.values()].map((item, i) => valueType._parse(new ParseInputLazyPath(ctx, item, ctx.path, i)));
    return ctx.common.async ? Promise.all(elements).then((elements2) => finalizeSet(elements2)) : finalizeSet(elements);
  }
  min(minSize, message) {
    return new ZodSet({
      ...this._def,
      minSize: { value: minSize, message: errorUtil.toString(message) }
    });
  }
  max(maxSize, message) {
    return new ZodSet({
      ...this._def,
      maxSize: { value: maxSize, message: errorUtil.toString(message) }
    });
  }
  size(size, message) {
    return this.min(size, message).max(size, message);
  }
  nonempty(message) {
    return this.min(1, message);
  }
};
ZodSet.create = (valueType, params) => new ZodSet({
  valueType,
  minSize: null,
  maxSize: null,
  typeName: ZodFirstPartyTypeKind.ZodSet,
  ...processCreateParams(params)
});
var ZodFunction = class extends ZodType {
  constructor() {
    super(...arguments), this.validate = this.implement;
  }
  _parse(input) {
    let { ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.function)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.function,
        received: ctx.parsedType
      }), INVALID;
    function makeArgsIssue(args, error) {
      return makeIssue({
        data: args,
        path: ctx.path,
        errorMaps: [
          ctx.common.contextualErrorMap,
          ctx.schemaErrorMap,
          getErrorMap(),
          errorMap
        ].filter((x) => !!x),
        issueData: {
          code: ZodIssueCode.invalid_arguments,
          argumentsError: error
        }
      });
    }
    function makeReturnsIssue(returns, error) {
      return makeIssue({
        data: returns,
        path: ctx.path,
        errorMaps: [
          ctx.common.contextualErrorMap,
          ctx.schemaErrorMap,
          getErrorMap(),
          errorMap
        ].filter((x) => !!x),
        issueData: {
          code: ZodIssueCode.invalid_return_type,
          returnTypeError: error
        }
      });
    }
    let params = { errorMap: ctx.common.contextualErrorMap }, fn = ctx.data;
    if (this._def.returns instanceof ZodPromise) {
      let me = this;
      return OK(async function(...args) {
        let error = new ZodError([]), parsedArgs = await me._def.args.parseAsync(args, params).catch((e) => {
          throw error.addIssue(makeArgsIssue(args, e)), error;
        }), result = await Reflect.apply(fn, this, parsedArgs);
        return await me._def.returns._def.type.parseAsync(result, params).catch((e) => {
          throw error.addIssue(makeReturnsIssue(result, e)), error;
        });
      });
    } else {
      let me = this;
      return OK(function(...args) {
        let parsedArgs = me._def.args.safeParse(args, params);
        if (!parsedArgs.success)
          throw new ZodError([makeArgsIssue(args, parsedArgs.error)]);
        let result = Reflect.apply(fn, this, parsedArgs.data), parsedReturns = me._def.returns.safeParse(result, params);
        if (!parsedReturns.success)
          throw new ZodError([makeReturnsIssue(result, parsedReturns.error)]);
        return parsedReturns.data;
      });
    }
  }
  parameters() {
    return this._def.args;
  }
  returnType() {
    return this._def.returns;
  }
  args(...items) {
    return new ZodFunction({
      ...this._def,
      args: ZodTuple.create(items).rest(ZodUnknown.create())
    });
  }
  returns(returnType) {
    return new ZodFunction({
      ...this._def,
      returns: returnType
    });
  }
  implement(func) {
    return this.parse(func);
  }
  strictImplement(func) {
    return this.parse(func);
  }
  static create(args, returns, params) {
    return new ZodFunction({
      args: args || ZodTuple.create([]).rest(ZodUnknown.create()),
      returns: returns || ZodUnknown.create(),
      typeName: ZodFirstPartyTypeKind.ZodFunction,
      ...processCreateParams(params)
    });
  }
}, ZodLazy = class extends ZodType {
  get schema() {
    return this._def.getter();
  }
  _parse(input) {
    let { ctx } = this._processInputParams(input);
    return this._def.getter()._parse({ data: ctx.data, path: ctx.path, parent: ctx });
  }
};
ZodLazy.create = (getter, params) => new ZodLazy({
  getter,
  typeName: ZodFirstPartyTypeKind.ZodLazy,
  ...processCreateParams(params)
});
var ZodLiteral = class extends ZodType {
  _parse(input) {
    if (input.data !== this._def.value) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        received: ctx.data,
        code: ZodIssueCode.invalid_literal,
        expected: this._def.value
      }), INVALID;
    }
    return { status: "valid", value: input.data };
  }
  get value() {
    return this._def.value;
  }
};
ZodLiteral.create = (value, params) => new ZodLiteral({
  value,
  typeName: ZodFirstPartyTypeKind.ZodLiteral,
  ...processCreateParams(params)
});
function createZodEnum(values, params) {
  return new ZodEnum({
    values,
    typeName: ZodFirstPartyTypeKind.ZodEnum,
    ...processCreateParams(params)
  });
}
var ZodEnum = class extends ZodType {
  _parse(input) {
    if (typeof input.data != "string") {
      let ctx = this._getOrReturnCtx(input), expectedValues = this._def.values;
      return addIssueToContext(ctx, {
        expected: util.joinValues(expectedValues),
        received: ctx.parsedType,
        code: ZodIssueCode.invalid_type
      }), INVALID;
    }
    if (this._def.values.indexOf(input.data) === -1) {
      let ctx = this._getOrReturnCtx(input), expectedValues = this._def.values;
      return addIssueToContext(ctx, {
        received: ctx.data,
        code: ZodIssueCode.invalid_enum_value,
        options: expectedValues
      }), INVALID;
    }
    return OK(input.data);
  }
  get options() {
    return this._def.values;
  }
  get enum() {
    let enumValues = {};
    for (let val of this._def.values)
      enumValues[val] = val;
    return enumValues;
  }
  get Values() {
    let enumValues = {};
    for (let val of this._def.values)
      enumValues[val] = val;
    return enumValues;
  }
  get Enum() {
    let enumValues = {};
    for (let val of this._def.values)
      enumValues[val] = val;
    return enumValues;
  }
  extract(values) {
    return ZodEnum.create(values);
  }
  exclude(values) {
    return ZodEnum.create(this.options.filter((opt) => !values.includes(opt)));
  }
};
ZodEnum.create = createZodEnum;
var ZodNativeEnum = class extends ZodType {
  _parse(input) {
    let nativeEnumValues = util.getValidEnumValues(this._def.values), ctx = this._getOrReturnCtx(input);
    if (ctx.parsedType !== ZodParsedType.string && ctx.parsedType !== ZodParsedType.number) {
      let expectedValues = util.objectValues(nativeEnumValues);
      return addIssueToContext(ctx, {
        expected: util.joinValues(expectedValues),
        received: ctx.parsedType,
        code: ZodIssueCode.invalid_type
      }), INVALID;
    }
    if (nativeEnumValues.indexOf(input.data) === -1) {
      let expectedValues = util.objectValues(nativeEnumValues);
      return addIssueToContext(ctx, {
        received: ctx.data,
        code: ZodIssueCode.invalid_enum_value,
        options: expectedValues
      }), INVALID;
    }
    return OK(input.data);
  }
  get enum() {
    return this._def.values;
  }
};
ZodNativeEnum.create = (values, params) => new ZodNativeEnum({
  values,
  typeName: ZodFirstPartyTypeKind.ZodNativeEnum,
  ...processCreateParams(params)
});
var ZodPromise = class extends ZodType {
  unwrap() {
    return this._def.type;
  }
  _parse(input) {
    let { ctx } = this._processInputParams(input);
    if (ctx.parsedType !== ZodParsedType.promise && ctx.common.async === !1)
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.promise,
        received: ctx.parsedType
      }), INVALID;
    let promisified = ctx.parsedType === ZodParsedType.promise ? ctx.data : Promise.resolve(ctx.data);
    return OK(promisified.then((data) => this._def.type.parseAsync(data, {
      path: ctx.path,
      errorMap: ctx.common.contextualErrorMap
    })));
  }
};
ZodPromise.create = (schema, params) => new ZodPromise({
  type: schema,
  typeName: ZodFirstPartyTypeKind.ZodPromise,
  ...processCreateParams(params)
});
var ZodEffects = class extends ZodType {
  innerType() {
    return this._def.schema;
  }
  sourceType() {
    return this._def.schema._def.typeName === ZodFirstPartyTypeKind.ZodEffects ? this._def.schema.sourceType() : this._def.schema;
  }
  _parse(input) {
    let { status, ctx } = this._processInputParams(input), effect = this._def.effect || null, checkCtx = {
      addIssue: (arg) => {
        addIssueToContext(ctx, arg), arg.fatal ? status.abort() : status.dirty();
      },
      get path() {
        return ctx.path;
      }
    };
    if (checkCtx.addIssue = checkCtx.addIssue.bind(checkCtx), effect.type === "preprocess") {
      let processed = effect.transform(ctx.data, checkCtx);
      return ctx.common.issues.length ? {
        status: "dirty",
        value: ctx.data
      } : ctx.common.async ? Promise.resolve(processed).then((processed2) => this._def.schema._parseAsync({
        data: processed2,
        path: ctx.path,
        parent: ctx
      })) : this._def.schema._parseSync({
        data: processed,
        path: ctx.path,
        parent: ctx
      });
    }
    if (effect.type === "refinement") {
      let executeRefinement = (acc) => {
        let result = effect.refinement(acc, checkCtx);
        if (ctx.common.async)
          return Promise.resolve(result);
        if (result instanceof Promise)
          throw new Error("Async refinement encountered during synchronous parse operation. Use .parseAsync instead.");
        return acc;
      };
      if (ctx.common.async === !1) {
        let inner = this._def.schema._parseSync({
          data: ctx.data,
          path: ctx.path,
          parent: ctx
        });
        return inner.status === "aborted" ? INVALID : (inner.status === "dirty" && status.dirty(), executeRefinement(inner.value), { status: status.value, value: inner.value });
      } else
        return this._def.schema._parseAsync({ data: ctx.data, path: ctx.path, parent: ctx }).then((inner) => inner.status === "aborted" ? INVALID : (inner.status === "dirty" && status.dirty(), executeRefinement(inner.value).then(() => ({ status: status.value, value: inner.value }))));
    }
    if (effect.type === "transform")
      if (ctx.common.async === !1) {
        let base = this._def.schema._parseSync({
          data: ctx.data,
          path: ctx.path,
          parent: ctx
        });
        if (!isValid(base))
          return base;
        let result = effect.transform(base.value, checkCtx);
        if (result instanceof Promise)
          throw new Error("Asynchronous transform encountered during synchronous parse operation. Use .parseAsync instead.");
        return { status: status.value, value: result };
      } else
        return this._def.schema._parseAsync({ data: ctx.data, path: ctx.path, parent: ctx }).then((base) => isValid(base) ? Promise.resolve(effect.transform(base.value, checkCtx)).then((result) => ({ status: status.value, value: result })) : base);
    util.assertNever(effect);
  }
};
ZodEffects.create = (schema, effect, params) => new ZodEffects({
  schema,
  typeName: ZodFirstPartyTypeKind.ZodEffects,
  effect,
  ...processCreateParams(params)
});
ZodEffects.createWithPreprocess = (preprocess, schema, params) => new ZodEffects({
  schema,
  effect: { type: "preprocess", transform: preprocess },
  typeName: ZodFirstPartyTypeKind.ZodEffects,
  ...processCreateParams(params)
});
var ZodOptional = class extends ZodType {
  _parse(input) {
    return this._getType(input) === ZodParsedType.undefined ? OK(void 0) : this._def.innerType._parse(input);
  }
  unwrap() {
    return this._def.innerType;
  }
};
ZodOptional.create = (type, params) => new ZodOptional({
  innerType: type,
  typeName: ZodFirstPartyTypeKind.ZodOptional,
  ...processCreateParams(params)
});
var ZodNullable = class extends ZodType {
  _parse(input) {
    return this._getType(input) === ZodParsedType.null ? OK(null) : this._def.innerType._parse(input);
  }
  unwrap() {
    return this._def.innerType;
  }
};
ZodNullable.create = (type, params) => new ZodNullable({
  innerType: type,
  typeName: ZodFirstPartyTypeKind.ZodNullable,
  ...processCreateParams(params)
});
var ZodDefault = class extends ZodType {
  _parse(input) {
    let { ctx } = this._processInputParams(input), data = ctx.data;
    return ctx.parsedType === ZodParsedType.undefined && (data = this._def.defaultValue()), this._def.innerType._parse({
      data,
      path: ctx.path,
      parent: ctx
    });
  }
  removeDefault() {
    return this._def.innerType;
  }
};
ZodDefault.create = (type, params) => new ZodDefault({
  innerType: type,
  typeName: ZodFirstPartyTypeKind.ZodDefault,
  defaultValue: typeof params.default == "function" ? params.default : () => params.default,
  ...processCreateParams(params)
});
var ZodCatch = class extends ZodType {
  _parse(input) {
    let { ctx } = this._processInputParams(input), newCtx = {
      ...ctx,
      common: {
        ...ctx.common,
        issues: []
      }
    }, result = this._def.innerType._parse({
      data: newCtx.data,
      path: newCtx.path,
      parent: {
        ...newCtx
      }
    });
    return isAsync(result) ? result.then((result2) => ({
      status: "valid",
      value: result2.status === "valid" ? result2.value : this._def.catchValue({
        get error() {
          return new ZodError(newCtx.common.issues);
        },
        input: newCtx.data
      })
    })) : {
      status: "valid",
      value: result.status === "valid" ? result.value : this._def.catchValue({
        get error() {
          return new ZodError(newCtx.common.issues);
        },
        input: newCtx.data
      })
    };
  }
  removeCatch() {
    return this._def.innerType;
  }
};
ZodCatch.create = (type, params) => new ZodCatch({
  innerType: type,
  typeName: ZodFirstPartyTypeKind.ZodCatch,
  catchValue: typeof params.catch == "function" ? params.catch : () => params.catch,
  ...processCreateParams(params)
});
var ZodNaN = class extends ZodType {
  _parse(input) {
    if (this._getType(input) !== ZodParsedType.nan) {
      let ctx = this._getOrReturnCtx(input);
      return addIssueToContext(ctx, {
        code: ZodIssueCode.invalid_type,
        expected: ZodParsedType.nan,
        received: ctx.parsedType
      }), INVALID;
    }
    return { status: "valid", value: input.data };
  }
};
ZodNaN.create = (params) => new ZodNaN({
  typeName: ZodFirstPartyTypeKind.ZodNaN,
  ...processCreateParams(params)
});
var BRAND = Symbol("zod_brand"), ZodBranded = class extends ZodType {
  _parse(input) {
    let { ctx } = this._processInputParams(input), data = ctx.data;
    return this._def.type._parse({
      data,
      path: ctx.path,
      parent: ctx
    });
  }
  unwrap() {
    return this._def.type;
  }
}, ZodPipeline = class extends ZodType {
  _parse(input) {
    let { status, ctx } = this._processInputParams(input);
    if (ctx.common.async)
      return (async () => {
        let inResult = await this._def.in._parseAsync({
          data: ctx.data,
          path: ctx.path,
          parent: ctx
        });
        return inResult.status === "aborted" ? INVALID : inResult.status === "dirty" ? (status.dirty(), DIRTY(inResult.value)) : this._def.out._parseAsync({
          data: inResult.value,
          path: ctx.path,
          parent: ctx
        });
      })();
    {
      let inResult = this._def.in._parseSync({
        data: ctx.data,
        path: ctx.path,
        parent: ctx
      });
      return inResult.status === "aborted" ? INVALID : inResult.status === "dirty" ? (status.dirty(), {
        status: "dirty",
        value: inResult.value
      }) : this._def.out._parseSync({
        data: inResult.value,
        path: ctx.path,
        parent: ctx
      });
    }
  }
  static create(a, b) {
    return new ZodPipeline({
      in: a,
      out: b,
      typeName: ZodFirstPartyTypeKind.ZodPipeline
    });
  }
}, ZodReadonly = class extends ZodType {
  _parse(input) {
    let result = this._def.innerType._parse(input);
    return isValid(result) && (result.value = Object.freeze(result.value)), result;
  }
};
ZodReadonly.create = (type, params) => new ZodReadonly({
  innerType: type,
  typeName: ZodFirstPartyTypeKind.ZodReadonly,
  ...processCreateParams(params)
});
var custom = (check, params = {}, fatal) => check ? ZodAny.create().superRefine((data, ctx) => {
  var _a, _b;
  if (!check(data)) {
    let p = typeof params == "function" ? params(data) : typeof params == "string" ? { message: params } : params, _fatal = (_b = (_a = p.fatal) !== null && _a !== void 0 ? _a : fatal) !== null && _b !== void 0 ? _b : !0, p2 = typeof p == "string" ? { message: p } : p;
    ctx.addIssue({ code: "custom", ...p2, fatal: _fatal });
  }
}) : ZodAny.create(), late = {
  object: ZodObject.lazycreate
}, ZodFirstPartyTypeKind;
(function(ZodFirstPartyTypeKind2) {
  ZodFirstPartyTypeKind2.ZodString = "ZodString", ZodFirstPartyTypeKind2.ZodNumber = "ZodNumber", ZodFirstPartyTypeKind2.ZodNaN = "ZodNaN", ZodFirstPartyTypeKind2.ZodBigInt = "ZodBigInt", ZodFirstPartyTypeKind2.ZodBoolean = "ZodBoolean", ZodFirstPartyTypeKind2.ZodDate = "ZodDate", ZodFirstPartyTypeKind2.ZodSymbol = "ZodSymbol", ZodFirstPartyTypeKind2.ZodUndefined = "ZodUndefined", ZodFirstPartyTypeKind2.ZodNull = "ZodNull", ZodFirstPartyTypeKind2.ZodAny = "ZodAny", ZodFirstPartyTypeKind2.ZodUnknown = "ZodUnknown", ZodFirstPartyTypeKind2.ZodNever = "ZodNever", ZodFirstPartyTypeKind2.ZodVoid = "ZodVoid", ZodFirstPartyTypeKind2.ZodArray = "ZodArray", ZodFirstPartyTypeKind2.ZodObject = "ZodObject", ZodFirstPartyTypeKind2.ZodUnion = "ZodUnion", ZodFirstPartyTypeKind2.ZodDiscriminatedUnion = "ZodDiscriminatedUnion", ZodFirstPartyTypeKind2.ZodIntersection = "ZodIntersection", ZodFirstPartyTypeKind2.ZodTuple = "ZodTuple", ZodFirstPartyTypeKind2.ZodRecord = "ZodRecord", ZodFirstPartyTypeKind2.ZodMap = "ZodMap", ZodFirstPartyTypeKind2.ZodSet = "ZodSet", ZodFirstPartyTypeKind2.ZodFunction = "ZodFunction", ZodFirstPartyTypeKind2.ZodLazy = "ZodLazy", ZodFirstPartyTypeKind2.ZodLiteral = "ZodLiteral", ZodFirstPartyTypeKind2.ZodEnum = "ZodEnum", ZodFirstPartyTypeKind2.ZodEffects = "ZodEffects", ZodFirstPartyTypeKind2.ZodNativeEnum = "ZodNativeEnum", ZodFirstPartyTypeKind2.ZodOptional = "ZodOptional", ZodFirstPartyTypeKind2.ZodNullable = "ZodNullable", ZodFirstPartyTypeKind2.ZodDefault = "ZodDefault", ZodFirstPartyTypeKind2.ZodCatch = "ZodCatch", ZodFirstPartyTypeKind2.ZodPromise = "ZodPromise", ZodFirstPartyTypeKind2.ZodBranded = "ZodBranded", ZodFirstPartyTypeKind2.ZodPipeline = "ZodPipeline", ZodFirstPartyTypeKind2.ZodReadonly = "ZodReadonly";
})(ZodFirstPartyTypeKind || (ZodFirstPartyTypeKind = {}));
var instanceOfType = (cls, params = {
  message: `Input not instance of ${cls.name}`
}) => custom((data) => data instanceof cls, params), stringType = ZodString.create, numberType = ZodNumber.create, nanType = ZodNaN.create, bigIntType = ZodBigInt.create, booleanType = ZodBoolean.create, dateType = ZodDate.create, symbolType = ZodSymbol.create, undefinedType = ZodUndefined.create, nullType = ZodNull.create, anyType = ZodAny.create, unknownType = ZodUnknown.create, neverType = ZodNever.create, voidType = ZodVoid.create, arrayType = ZodArray.create, objectType = ZodObject.create, strictObjectType = ZodObject.strictCreate, unionType = ZodUnion.create, discriminatedUnionType = ZodDiscriminatedUnion.create, intersectionType = ZodIntersection.create, tupleType = ZodTuple.create, recordType = ZodRecord.create, mapType = ZodMap.create, setType = ZodSet.create, functionType = ZodFunction.create, lazyType = ZodLazy.create, literalType = ZodLiteral.create, enumType = ZodEnum.create, nativeEnumType = ZodNativeEnum.create, promiseType = ZodPromise.create, effectsType = ZodEffects.create, optionalType = ZodOptional.create, nullableType = ZodNullable.create, preprocessType = ZodEffects.createWithPreprocess, pipelineType = ZodPipeline.create, ostring = () => stringType().optional(), onumber = () => numberType().optional(), oboolean = () => booleanType().optional(), coerce = {
  string: (arg) => ZodString.create({ ...arg, coerce: !0 }),
  number: (arg) => ZodNumber.create({ ...arg, coerce: !0 }),
  boolean: (arg) => ZodBoolean.create({
    ...arg,
    coerce: !0
  }),
  bigint: (arg) => ZodBigInt.create({ ...arg, coerce: !0 }),
  date: (arg) => ZodDate.create({ ...arg, coerce: !0 })
}, NEVER = INVALID, z = /* @__PURE__ */ Object.freeze({
  __proto__: null,
  defaultErrorMap: errorMap,
  setErrorMap,
  getErrorMap,
  makeIssue,
  EMPTY_PATH,
  addIssueToContext,
  ParseStatus,
  INVALID,
  DIRTY,
  OK,
  isAborted,
  isDirty,
  isValid,
  isAsync,
  get util() {
    return util;
  },
  get objectUtil() {
    return objectUtil;
  },
  ZodParsedType,
  getParsedType,
  ZodType,
  ZodString,
  ZodNumber,
  ZodBigInt,
  ZodBoolean,
  ZodDate,
  ZodSymbol,
  ZodUndefined,
  ZodNull,
  ZodAny,
  ZodUnknown,
  ZodNever,
  ZodVoid,
  ZodArray,
  ZodObject,
  ZodUnion,
  ZodDiscriminatedUnion,
  ZodIntersection,
  ZodTuple,
  ZodRecord,
  ZodMap,
  ZodSet,
  ZodFunction,
  ZodLazy,
  ZodLiteral,
  ZodEnum,
  ZodNativeEnum,
  ZodPromise,
  ZodEffects,
  ZodTransformer: ZodEffects,
  ZodOptional,
  ZodNullable,
  ZodDefault,
  ZodCatch,
  ZodNaN,
  BRAND,
  ZodBranded,
  ZodPipeline,
  ZodReadonly,
  custom,
  Schema: ZodType,
  ZodSchema: ZodType,
  late,
  get ZodFirstPartyTypeKind() {
    return ZodFirstPartyTypeKind;
  },
  coerce,
  any: anyType,
  array: arrayType,
  bigint: bigIntType,
  boolean: booleanType,
  date: dateType,
  discriminatedUnion: discriminatedUnionType,
  effect: effectsType,
  enum: enumType,
  function: functionType,
  instanceof: instanceOfType,
  intersection: intersectionType,
  lazy: lazyType,
  literal: literalType,
  map: mapType,
  nan: nanType,
  nativeEnum: nativeEnumType,
  never: neverType,
  null: nullType,
  nullable: nullableType,
  number: numberType,
  object: objectType,
  oboolean,
  onumber,
  optional: optionalType,
  ostring,
  pipeline: pipelineType,
  preprocess: preprocessType,
  promise: promiseType,
  record: recordType,
  set: setType,
  strictObject: strictObjectType,
  string: stringType,
  symbol: symbolType,
  transformer: effectsType,
  tuple: tupleType,
  undefined: undefinedType,
  union: unionType,
  unknown: unknownType,
  void: voidType,
  NEVER,
  ZodIssueCode,
  quotelessJson,
  ZodError
});

// src/workers/shared/zod.worker.ts
var HEX_REGEXP = /^[0-9a-f]*$/i, BASE64_REGEXP = /^[0-9a-z+/=]*$/i, HexDataSchema = z.string().regex(HEX_REGEXP).transform((hex) => Buffer.from(hex, "hex")), Base64DataSchema = z.string().regex(BASE64_REGEXP).transform((base64) => Buffer.from(base64, "base64"));
export {
  BASE64_REGEXP,
  Base64DataSchema,
  HEX_REGEXP,
  HexDataSchema,
  z
};
//# sourceMappingURL=zod.worker.js.map
//# sourceURL=file:///C:/Users/joshr/AppData/Local/Temp/bunx-3240478352-selflare@latest/node_modules/selflare/dist/workers/shared/zod.worker.js      2  workerd-autogate-builtin-wasm-modules   