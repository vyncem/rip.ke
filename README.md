# README

Rip.ke is a small Rails app that edits the Jekyll content for
[rip-coke/rip](https://github.com/rip-coke/rip) through the GitHub API.

## Content editing

Signed-in users can create, view, edit and delete:

* **Posts** – files in `_posts/` (`/posts`)
* **Pages** – files in `_pages/` (`/pages`)
* **Notices** – files in `_notices/` (`/homes`)

Posts and pages are read from the user's draft branch when it exists, otherwise
from the base branch. Every save is committed to a per-user `draft` branch and
proposed as a pull request, so nothing goes live until it is merged.

The post/page forms support a title, date (posts), layout, permalink (pages),
the markdown/HTML body and an advanced YAML front matter box. Existing front
matter keys that the form does not show (for example `pic`, `header` or
`excerpt`) are preserved when a document is edited.

## Configuration

The following environment variables are used:

| Variable | Default | Purpose |
| --- | --- | --- |
| `GITHUB_TOKEN` | – | Token with permission to read/write the content repository |
| `GITHUB_REPO` | `rip-coke/rip` | Repository that stores the Jekyll site |
| `BASE_BRANCH` | `master` | Branch that pull requests target |
| `POSTS_FOLDER` | `_posts` | Folder containing posts |
| `PAGES_FOLDER` | `_pages` | Folder containing pages |
| `DEFAULT_POST_LAYOUT` | `post` | Layout used for new posts |
| `DEFAULT_PAGE_LAYOUT` | `default` | Layout used for new pages |

For the current content repository the Jekyll site lives on the `rip` branch,
so set `BASE_BRANCH=rip` when running against it.

## Setup

```sh
bin/setup
bin/rails server
```

Run the tests with:

```sh
bin/rails test
```
