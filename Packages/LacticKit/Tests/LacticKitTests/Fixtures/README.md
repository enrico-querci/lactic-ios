# Fixtures

Responses captured verbatim from a running `lactic-api` (`bin/rails dev:seed`,
then a walk through the client flow with `curl`). They are real bytes rather
than hand-written approximations, which is the point: they catch the difference
between what the contract implies and what the API actually sends.

**Credentials are scrubbed.** `auth_response.json` originally carried a real
access token and refresh token. The access token is an HS256 JWT signed with
`Rails.application.credentials.jwt_secret_key` — the same key production uses —
so its signature is replaced with a constant. The refresh token is zeroed. Both
keep their original shape, and the tests assert shape rather than value.

Everything else is seed data: `alice@example.com` and friends exist only in a
local development database.

To refresh these, run the API locally and re-capture — then scrub
`auth_response.json` again before committing.
