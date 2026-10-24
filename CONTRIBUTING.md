# Contributing

Thank you for looking at the code. You can report a problem in an issue, or
send a change as a pull request.

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

Each commit in this repository is the source of one released version, so
a pull request is not merged here. Your change goes into the next release
instead:

1. Fork this repository, make your change on a branch, and open a pull
   request against `main`.
2. We review it here, in the open, and may ask for changes.
3. When it is ready, we bring it into the next release. The commit of that
   release lists your pull request and names you as a co-author.
4. When that release is published here, we close your pull request with a
   comment that names the release. It is closed rather than merged, because
   the commit of the release already holds your change.

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
- Not `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/`,
  `lib/api/built_in.dart` or `assets/fallback/index.txt`. This copy has its
  own versions of these files. Suggest a change to them in an issue.
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

## Security problems

Do not open an issue. See [SECURITY.md](SECURITY.md).
