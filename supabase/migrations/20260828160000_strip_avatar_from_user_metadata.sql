-- Take the profile picture back out of auth user metadata.
--
-- ProfileImagePickerService used to write the picked photo into two places: the
-- profiles row, and the auth user's metadata as 'avatar_url'. Both copies held
-- the whole image as a base64 data URI.
--
-- The metadata copy is the problem. Supabase embeds user_metadata in every
-- access token, so a photo there does not sit quietly in a column — it is
-- carried in the Authorization header of every single request the app makes.
-- A 512x512 JPEG is tens of kilobytes once base64'd and wrapped in a JWT, which
-- pushes the header past the ~16KB the API gateway accepts. Past that point the
-- proxy rejects the request with a bare HTML "400 Bad Request" before it ever
-- reaches Postgres or an edge function, so the account cannot pay, subscribe,
-- or load data. Nothing in the app reports a useful cause for that, because
-- nothing in the app ever ran.
--
-- The client no longer writes it. This clears what is already stored, so
-- existing accounts stop shipping an image in their headers. profiles
-- .profile_picture_url keeps the picture and is what every reader now uses, so
-- no photo is lost.
--
-- Affected users must sign out and back in (or wait for their access token to
-- refresh) to be issued a token minted from the trimmed metadata — the token
-- already on the device keeps the embedded copy until it is reissued.

update auth.users
set raw_user_meta_data = raw_user_meta_data - 'avatar_url'
where raw_user_meta_data ? 'avatar_url';
