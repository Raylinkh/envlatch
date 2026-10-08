# HTTP header diagnostics

Verified 2026-10-07 in LayerProof's bounded Python image client. EnvLatch supplies the selected value; the consumer owns the recipient's input contract and error output. This does not add redaction to EnvLatch or change a stored credential.

The initial client accepted a public fake key containing CR/LF. An independent transport-controlled CLI test reproduced an HTTP header validation error containing the complete fake Bearer value. The client copied the exception into both its receipt and stderr. No real credential or network request was used in the test.

The corrected client refuses control/unsupported characters with a fixed diagnostic before GET, POST or call reservation. The unchanged test verifies that neither the fake key nor an authorization header appears in diagnostics. The supported key shape remains specific to that API. This finding does not justify stripping whitespace from arbitrary credentials.

For a client using a saved key in a single-line HTTP header:

1. Validate the recipient's allowed character shape before transport.
2. Use a constant failure message for invalid credential input.
3. Avoid recording an exception whose message may contain the header value.
4. Verify the negative case with a public sentinel and stubbed transport, never a real key.

Evidence: [independent proof and exact source hashes](/Users/kehualin/Documents/projects/raylin-lab/apps/layerproof/docs/experiments/scene-motion/proof/REPORT.md), [RED control](/Users/kehualin/Documents/projects/raylin-lab/apps/layerproof/docs/experiments/scene-motion/proof/header-all-red-2830215/header-results.json), [integrated GREEN](/Users/kehualin/Documents/projects/raylin-lab/apps/layerproof/docs/experiments/scene-motion/proof/root-boundary-final/transport/header-results.json).

## Native curl without credential arguments

Verified 2026-10-09 in one Selenar editorial request. The selected key reached curl through an in-memory config on stdin. Resend accepted the request, and retrieval of that exact message reported delivered. No credential value appeared in arguments, files or diagnostics. A Python metadata request returned403 while the documented native client returned authorized200 with the same selected key; the specific403 cause remains unverified. This is not permission to bypass an authorization denial or expand key scope.

For a provider that documents curl:

1. Keep the normal selected-key EnvLatch wrapper. Validate the credential's single-line header shape before transport.
2. Construct the curl config inside the credential-bearing child and pass it to `curl --config -` on stdin. Quote config values correctly. Keep the key out of arguments, shell interpolation and temporary files.
3. Keep normal TLS verification, omit redirect following and avoid verbose/trace output. Retain only allowlisted status fields rather than raw stderr or exceptions.
4. Persist an idempotency key and the exact non-secret payload before a send. Preserve an uncertain outcome; never retry with a new key or changed payload. Follow the provider's retention limit.
5. Retrieve only that operation's receipt. Accepted, delivered, read and the product outcome are separate claims.

Evidence: [executed consumer](/Users/kehualin/Documents/projects/onyourfeet/docs/distribution/2026-10-09-first-download/macstories-outreach/transport.py), [bounded acceptance and delivery](/Users/kehualin/Documents/projects/onyourfeet/docs/distribution/2026-10-09-first-download/macstories-outreach/submission.json), [Resend idempotency contract](https://resend.com/docs/api-reference/emails/send-email), [message retrieval](https://resend.com/docs/api-reference/emails/retrieve-email).
