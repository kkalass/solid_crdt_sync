# TODO

## Up Next
- [ ] Set up sync structure: enhance SolidCrdtSync with SyncStatus stream or similar, allow manual triggering of sync, but also allow configuring/controlling automatic sync and implement the triggering (even though the sync itself will not do anything yet)
- [ ] Clarify: I am thinking about adding something like SolidCrdtGraphSync which would be similar to SolidCrdtSync, but not based on dart objects + mapper, but on pure RdfGraph instances. The Idea is, that SolidCrdtGraphSync should be used by SolidCrdtSync for the actual work, so that SolidCrdtSync itself adds the dart object conversion on top of the more basic sync service. Clarify if I want to do it now or possibly later
- [ ] Clarify: What is the most-user-friendly way to approach http? should we simply assume that we are provided with http client, or is it best practice for a library like ours to abstract this away? Remember: http would need to be integrated with solid DPoP, is this in our control, or should we offload it to the developer?

## Later
- [ ] Final check if the spec in ARCHITECTURE.md is fully implemented

## Done
- [x] Migrate to W3ID.org permanent IRIs
- [x] Clarify: can we include localhost into the client-config.json document to support local debugging? Or should we rather not do that since it would open up our app to attacks? => better not, plus: removed linux/windows support and adviced against those platforms
