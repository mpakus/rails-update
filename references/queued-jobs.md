# Queued jobs across Ruby and Rails versions

Read when an upgrade changes job classes, argument signatures, serializers or
mail delivery. New enqueue specs and a green suite do not establish that jobs
already stored by the previous runtime can execute.

## Capture the actual wire format

Generate synthetic payload fixtures using the old Ruby, Rails and queue-adapter
versions. Record the generator, runtime and lockfile identity; retain these
fixtures independently of the target serializer. Inspect class names, argument
order, hash-key metadata, GlobalIDs, queue names and retry metadata. Exercise the
real deserializer and backend wrapper in isolation with an in-memory delivery
transport. Calling `perform` directly bypasses constant lookup and serialization.
Do not consume real jobs to test compatibility. Unsupported payload formats do
not establish that a production backlog exists; report backlog size as unknown
until an authorized read-only inventory verifies it.

## Legacy Action Mailer jobs

Rails 5.2 stored `ActionMailer::DeliveryJob` and
`ActionMailer::Parameterized::DeliveryJob`. Ordinary jobs used positional mailer
arguments; parameterized jobs placed params before those arguments. Modern
`ActionMailer::MailDeliveryJob` accepts `args:`, optional `kwargs:` and `params:`.
Compare the [old ordinary job](https://github.com/rails/rails/blob/v5.2.8.1/actionmailer/lib/action_mailer/delivery_job.rb),
[old parameterized job](https://github.com/rails/rails/blob/v5.2.8.1/actionmailer/lib/action_mailer/parameterized.rb)
and [target implementation](https://github.com/rails/rails/blob/v8.1.0/actionmailer/lib/action_mailer/mail_delivery_job.rb)
with the app's installed versions.

Use the configured mailer's `delivery_job` in new enqueue assertions. That fixes
an obsolete test constant, not the old queue's reader. A class alias or payload
class-name substitution alone cannot translate the different argument layout.
If old jobs must survive, keep narrowly scoped readers for the old class names
and translate their arguments into the current delivery contract. Leave new
enqueue behavior on the current job class and test cold Rails autoload/eager-load
and reload of the compatibility readers.

Ruby 2-era payloads can contain a trailing hash without today's keyword marker.
Preserve both positional-hash mailer methods and keyword mailer methods. Restore
legacy forwarding only at the proven compatibility boundary; indiscriminate
`**hash`, key symbolization or flattening can corrupt data or reject a valid
positional API. Where `Hash.ruby2_keywords_hash` is used, verify that the installed
Active Job serializer preserves the intended semantics after retry/reserialization.
Treat parameterized mailer params separately from its method arguments.

## Application job signatures

A former `perform(id, options = {})` job changed to `perform(id, force: false)`
can accept every new enqueue and still reject old serialized `[id, {force: true}]`.
Inspect controller, task and scheduler producers as well as the worker. If a
compatibility reader accepts both forms, explicitly define precedence for a
payload containing both; preserve false, nil and omitted values according to the
old contract rather than using truthiness to choose a default.

## Required evidence for the applicable formats

| Case | Observe |
| --- | --- |
| Old ordinary and parameterized mail | Correct recipient/body, params and arguments through actual job execution |
| Positional hash and keywords | Each reaches its intended method unchanged; include empty hash and no arguments |
| Application options | Old/new format, absent, true and false; nil or combined forms when supported |
| New jobs | Current class and serializer remain in use; same queue and delivery behavior |
| Retry/reserialization | Class, queue, job identity, execution count and argument meaning survive |
| Failure and GlobalID | Intended exception handling and retry policy; deleted record behavior if relevant |
| Cold boot/reload | Compatibility constants resolve under the application's loader |

## Cutover and removal

Choose between compatibility readers and an explicitly planned drain. A drain
must stop old producers and account for ready, delayed/scheduled and failed/retry
jobs; an empty ready queue alone is insufficient. Keep readers until no retained
queue state can reintroduce the old format. Record the removal condition and
evidence, not just a calendar date. Do not rewrite or discard queue data as an
unreviewed repair.

Test the reverse direction when rollback can send new jobs to old workers. If
that direction is incompatible, define worker/producer ordering and the recovery
plan before release. Queue compatibility and storage-schema compatibility are
separate cutover gates; see [release and rollback](verification.md#release-and-rollback).
