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
