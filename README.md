# Nook — Campus Community & Lost and Found

Nook is a Flutter application backed by Supabase. It combines a campus social feed, student communities, threaded discussions, and a Lost & Found board.

## Main features

- Email/password registration and login.
- Student profile with editable name and phone number.
- Campus feed for public posts, with text and up to five photos.
- Post likes and comments.
- Nested replies to comments, with owner-only comment deletion.
- Student-created groups and group membership requests.
- Creator/admin approval or rejection of group join requests.
- Group-only discussions with text and photo posts.
- Creator-only group deletion, with database cascades for related records.
- Lost & Found listings with search, photos, owner contact details, and resolved status.
- One-tap contact from a listing: Call, WhatsApp (with a pre-written message) and Email, plus long-press to copy the number or address. Hidden on your own posts.
- Full-screen, pinch-to-zoom photo viewer on the listing details screen.
- LOST / FOUND / RESOLVED badges and "posted 3 hr ago" timestamps.
- Group join requests inbox at the top of the Groups tab: a notification card ("You have 3 requests waiting for approval") that expands to approve or reject requests from every group you manage, without opening each group. It hides itself when nothing is pending and the count updates immediately after each action.
- Redesigned sign-in and register screens: painted navy "aurora" backdrop (no image assets), floating form card, inline validation, show/hide password, password-manager autofill, password strength meter, confirm-password field, "Did you mean gmail.com?" typo suggestions, friendly error messages and a clear "check your inbox" state after sign-up.
- My Posts view for a student's Lost & Found listings.
- Light and dark appearance modes.
- Responsive Flutter UI with an Apple-inspired visual system: restrained colors, system typography, generous spacing, rounded surfaces, and clear hierarchy.

## Requirements

- Flutter SDK compatible with Dart 3.
- A Supabase project.
- An internet connection for Supabase Auth, Database, and Storage.

## Setup

1. Open the project folder in Android Studio or VS Code.
2. Check `lib/config/supabase_config.dart` and set your Supabase project URL and publishable/anon key.
3. If your phone numbers are usually saved without a country code, set `AppConfig.defaultCountryCode` in `lib/config/app_config.dart` (default `91`). It is only used to build WhatsApp links.
4. Install packages (this fetches `url_launcher`, used for the Call / WhatsApp / Email buttons):

   ```bash
   flutter pub get
   ```

5. Apply the SQL migrations in order in Supabase SQL Editor:

   - `supabase/migrations/202611060001_nook_social_feed.sql`
   - `supabase/migrations/202611060002_nook_communities_photos.sql`
   - `supabase/migrations/202611070001_nook_feature_completion.sql`

   The final migration is written to reconcile the group request, nested comment, role, access-policy, and cascade requirements. If you already applied equivalent SQL manually, review the migration before running it in production.

6. Ensure the `item-images` Storage bucket exists and has policies that allow authenticated users to upload to their own item paths. The second migration creates the public `post-images` bucket and its upload/view/delete policies.
7. Run the app:

   ```bash
   flutter run
   ```

   For Chrome:

   ```bash
   flutter run -d chrome
   ```

## Important data and storage notes

- Group posts use `visibility = 'community'` and are loaded only inside their group. The campus feed excludes posts with a `group_id`.
- Membership is granted through `review_group_join_request`; the client does not directly add a requester as a member.
- Deleting a group cascades through its database records (posts, comments, likes, memberships, and join requests) when the final migration's foreign-key rules are in place.
- Supabase Storage objects are separate from database rows. Group deletion does not automatically remove photos from `post-images`; storage cleanup needs a trusted server-side cleanup process if that is required.
- Never put a Supabase `service_role` key in the Flutter application. Only the publishable/anon key belongs in a client app; enforce access through Row Level Security.

## Project structure

```text
lib/
  config/       Supabase configuration and app settings
  models/       Item, user, group, and social-post models
  screens/      Authentication, feed, groups, comments, and Lost & Found UI
  services/     Supabase Auth, database, and Storage operations
  theme/        Light/dark Apple-inspired theme
  utils/        Pure-Dart helpers (phone/WhatsApp/mail links, relative time, auth validation)
  widgets/      Reusable UI components
supabase/
  migrations/   Database schema and RLS migrations
```
