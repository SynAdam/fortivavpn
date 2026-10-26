# Contributing

Thank you for looking at the code. You can report a problem in an issue, or
send a change as a pull request.

## Where to start

- **Good first issues.** Issues labelled
  [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue)
  are small and clearly described, so they make a good first change.
- **Help wanted.** Issues labelled
  [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted)
  are ones we would like help with. Say in the issue that you are working on
  one, so that two people do not do the same work.
- **Translations.** The app's text is in [`lib/l10n/`](lib/l10n/), one file
  for each language, named `app_<code>.arb`. English, `app_en.arb`, is the
  source, and the other files translate it. The codes are `ar`, `de`, `en`,
  `es`, `fa`, `fr`, `hi`, `id`, `ja`, `ko`, `pt`, `ru`, `tr`, `uk`, `ur`,
  `uz`, `vi` and `zh`. A fix to one translated string is a good first pull
  request.

For a translation:

- Keep every placeholder in braces, such as `{query}`, exactly as it is.
  `test/arb_keys_test.dart` checks that each language has the same keys and
  placeholders as `app_en.arb`.
- A new string goes into every `.arb` file, not only the English one.
- Run `flutter gen-l10n`, which writes `lib/l10n/generated/` from the
  `.arb` files as [`l10n.yaml`](l10n.yaml) sets out, then
  `dart format lib/ test/`. Commit the generated files with your change.

## Issues

Open an issue for a bug, a connection problem or an idea. It helps to say:

- the app version (Settings shows it) and where you installed it from;
- the device, the system version and, for a connection problem, the network
  (operator, mobile data or Wi-Fi, and the country you are in);
- what you did, what you expected, and what happened instead.

Never post a link the app gave you (from Copy link), an account code, or a
screenshot that shows one. Anyone who has it can use your account.

Write in English or Persian.

<div dir="rtl">

برای گزارش مشکل یا پیشنهاد، یک issue باز کنید و فارسی یا انگلیسی بنویسید. همه می‌توانند issueها را ببینند، پس لینکی که اپ به شما داده یا کد حساب‌تان را در آن ننویسید. برای تغییر کد، یک pull request بفرستید. مراحل و شرایط آن در همین فایل آمده است.

</div>

## Pull requests

This repository gets its commits from our private repository at each
release, so a pull request is not merged here. Your change goes into the
next release instead:

1. Fork this repository, make your change on a branch, and open a pull
   request against `main`.
2. We review it here, in the open, and may ask for changes.
3. When it is ready, we bring it into the next release. The commit that
   brings your change here lists your pull request and names you as a
   co-author.
4. When that release is published here, we close your pull request with a
   comment that names the release. It is closed rather than merged, because
   a commit of the release already holds your change.

The co-author line has the name on your GitHub profile, or your username if
the profile has no name, and your GitHub no-reply email address. Other
people in your pull request are credited the same way when GitHub links
their commits to their account, or when a `Co-authored-by` line in a commit
gives their GitHub no-reply address.

For a large change, open an issue first so that we can agree on it before
you start.

What a pull request can change:

- The code and tests of the app, such as `lib/`, `test/`, `android/` and
  `windows/`.
- Not the files that this copy has its own versions of: `README.md`,
  `README.fa.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
  `SUPPORT.md`, `CHANGELOG.md` and `.gitignore` at the top level, anything
  under `.github/`, `lib/api/built_in.dart` and `assets/fallback/index.txt`.
  Suggest a change to them in an issue.
- Not `.gitattributes` or `.gitmodules`, in any folder.
- No binary files, such as images or libraries, and no symlinks or
  submodules. If your change needs one, say so in the pull request.

Before you open it, check that these pass:

```bash
dart format lib/ test/
flutter analyze --fatal-infos
flutter test
```

Add a test for what you fix or add. In tests, use the documentation
addresses (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` and
`2001:db8::/32`) instead of real ones. Never put a link the app gave you or
an account code in a pull request.

## Labels

The issue forms add `bug`, `enhancement` or `translation`. We add the
others.

| Label | What it means |
| --- | --- |
| `bug` | Something in the app does not work as it should. |
| `connection` | The app cannot connect, or the connection drops or is slow. |
| `enhancement` | An idea for something new, or for something that could work better. |
| `translation` | Text in one of the app's languages is wrong, unclear or missing. |
| `android` | It is about Android phones. |
| `android tv` | It is about Android TV. |
| `accessibility` | Something makes the app hard to use for people with disabilities. |
| `documentation` | The README, these guides or other documentation. |
| `good first issue` | Small and clearly described: a good first change. |
| `help wanted` | We would like help with it. |
| `question` | The issue asks a question. |
| `needs info` | We are waiting for more details from the person who opened it. |
| `in next release` | Accepted. The change ships in the next release. |
| `duplicate` | Another issue or pull request already covers it. |
| `invalid` | It is not a problem in the app, or there is not enough in it to act on. |
| `wontfix` | We decided not to make this change. |

## Terms

By opening a pull request, you agree that:

- your change is under this repository's licence, [LICENSE](LICENSE);
- the copyright holder, NimusAI, may also ship your change in its other
  builds of the app under other terms.

The second point is needed because the same code goes into more than one
build. The Android and Windows builds are GPL-3.0. The iOS build contains
no GPL code and is not GPL, and the code in `lib/` goes into all of them.
[LICENSING.md](LICENSING.md) says which build is under which terms, and
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lists every component.

Code in `lib/` goes into every build, and code in `ios/` goes into the iOS
build. Code you send for these folders must be your own work, or under a
licence that allows it in a build that is not GPL, such as MIT or BSD.
GPL-3.0 code can go only into `android/` and `windows/`, which are part of
the Android and Windows builds alone.

## Code of conduct

Everyone who takes part in this project follows the
[code of conduct](CODE_OF_CONDUCT.md). To report a problem, email
admin@fortivavpn.com with "Conduct" in the subject.

## Security problems

Do not open an issue. See [SECURITY.md](SECURITY.md).
