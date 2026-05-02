# CLAUDE.md

このリポジトリで Claude Code (claude.ai/code) が作業する際のガイダンス。

## コミット運用

- **コミットしたら必ず origin に push すること**。
  - このリポジトリは複数の consumer アプリ (例: vlc-multi-video-player) から
    Swift Package Manager で `branch: master` 指定で参照されている。
  - ローカルにのみ commit が残った状態だと consumer 側でビルドが落ちたり、
    そもそも変更が反映されないため、commit と push はセットで行う。
  - `git commit && git push origin master` を癖にする。
