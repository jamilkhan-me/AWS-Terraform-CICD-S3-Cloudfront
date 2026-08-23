# Bootstrap (apply this once, manually, before setting up CI)

CI/CD needs two things that can't be created by the CI pipeline itself, because the pipeline
needs them to exist first — a classic bootstrapping problem:

1. **Remote state storage** — an S3 bucket (+ DynamoDB lock table) so `terraform.tfstate` isn't
   sitting on a laptop or, worse, a GitHub Actions runner that disappears after every job.
2. **A way for GitHub Actions to authenticate to AWS without long-lived credentials** — an OIDC
   identity provider + an IAM role that only your specific GitHub repo can assume, scoped to only
   the permissions the main project needs.

Run this from your own machine, once, with your own AWS credentials:

```bash
cd bootstrap
terraform init
terraform apply \
  -var="github_repository=YOUR_GITHUB_USERNAME/YOUR_REPO_NAME"
```

Note the two outputs: `state_bucket_name` and `github_actions_role_arn`. You'll need both:

- Put `state_bucket_name` into `../versions.tf`'s `backend "s3"` block (`bucket = "..."`).
- Put `github_actions_role_arn` into a GitHub Actions repository secret named `AWS_ROLE_ARN`
  (Settings → Secrets and variables → Actions → New repository secret).

This bootstrap config intentionally has its **own local state** — it's applied once by a human,
not by CI, so there's no chicken-and-egg problem to solve for it.

## Why OIDC instead of access keys

A GitHub Actions secret holding a long-lived `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` pair is a
standing credential that works forever if it leaks. The OIDC role trust policy here instead lets
GitHub's token service vouch for "this run really is `YOUR_REPO`, on branch `main`" and AWS hands
out a *temporary* credential for that one job run only. This is the current AWS-recommended
pattern for GitHub Actions → AWS and a good thing to be able to explain in an interview.
