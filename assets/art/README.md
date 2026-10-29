# Kipto artwork

Original AI-generated decorative illustrations created for this app:

- `wallet.png`: wallet, card, receipt, and coins for the spending summary.
- `receipt.png`: receipt and coins for empty expense lists.

Both files have transparent backgrounds and are bundled locally through
`pubspec.yaml`. They do not require a network request, include user data, or
indicate account or backup status. The original images are kept at their
generated resolution so they remain sharp on high-density displays.

`KiptoArt` excludes decorative images from screen-reader semantics. The summary
hides its illustration on narrow layouts and at larger text sizes to make room
for the amount and period. Light and dark themes share the same artwork.
