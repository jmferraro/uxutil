// claude-fetch.js -- save one claude.ai conversation as JSON, from the browser.
//
// WHY THIS AND NOT A SHELL SCRIPT:
//   The conversation list is virtualised, so "Save Page As" only ever captures
//   the handful of turns currently mounted in the DOM.  The full transcript is
//   already on the client though -- the web app fetches it in one JSON request.
//   This just re-issues that request and hands you the response.
//
//   Run from the page itself and the session cookie (HttpOnly, unreadable from
//   JS) rides along automatically on a same-origin fetch.  Nothing is extracted,
//   stored, or published: no token on disk, no public /share/ link.
//
// USE:
//   1. open the conversation at https://claude.ai/chat/<uuid>
//   2. F12 > Console.  Chrome blocks pasting until you type: allow pasting
//   3. paste this whole file, Enter.  A .json file downloads.
//   4. scp it to wherever claude2md lives:   claude2md -a conv.json > conv.md
//
// Add ?all=1 style bulk export is deliberately omitted -- for the whole account
// use Settings > Privacy > Export data, which is the supported route.

(async () => {
  const get = async (url) => {
    const r = await fetch(url, {
      credentials: 'include',
      headers: { accept: 'application/json' },
    });
    if (!r.ok) throw new Error(`${url} -> HTTP ${r.status}`);
    return r.json();
  };

  const id = location.pathname.split('/chat/')[1]?.split(/[?#]/)[0];
  if (!id) throw new Error('Open a https://claude.ai/chat/<uuid> page first.');

  // An account can hold several orgs; an api-only one 404s every chat endpoint.
  // Pick the org that actually advertises "chat" rather than assuming orgs[0].
  const raw = await get('/api/organizations');
  const orgs = Array.isArray(raw) ? raw : (raw.organizations || []);
  const org = (orgs.find((o) => (o.capabilities || []).includes('chat')) || orgs[0])?.uuid;
  if (!org) throw new Error('No organization found on this account.');

  // rendering_mode=messages is required: without it messages arrive as a flat
  // string with no content[] at all, and every tool block collapses to a
  // "not supported on your current device" placeholder.  render_all_tools
  // restores real tool input/output.  tree=True includes abandoned branches --
  // claude2md walks current_leaf_message_uuid back to the root to undo that.
  const q = 'tree=True&rendering_mode=messages&render_all_tools=true';
  const conv = await get(`/api/organizations/${org}/chat_conversations/${id}?${q}`);

  const name = (conv.name || id).replace(/[^\w.-]+/g, '_').slice(0, 60);
  const a = document.createElement('a');
  a.href = URL.createObjectURL(
    new Blob([JSON.stringify(conv, null, 2)], { type: 'application/json' }),
  );
  a.download = `${name}-${id.slice(0, 8)}.json`;
  a.click();
  URL.revokeObjectURL(a.href);

  console.log(`saved "${conv.name}" -- ${(conv.chat_messages || []).length} messages`);
})();
