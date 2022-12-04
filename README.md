Register Azure app
  - https://gitlab.com/muttmua/mutt/-/blob/master/contrib/mutt_oauth2.py.README#L184
  - Get client_id, tenant_id a client_secret (only for private apps, for public apps leave empty later)
  
Add gems to Gemfile.local
  - oauth2
  - gmail_xoauth

Patch lib/task/imap.rb
  - patch < lib_redmine_imap.patch

Add task into lib/tasks
  - lib/task/email_oauth.rake

Run bundle install

Init email account token (interactive)
- ``rake redmine:email:o365_oauth2_init token_file=/app/redmine/config/email_oauth2 client=uuid tenant=uuid secret=key``

Download emails
- params are same as standart rake task, password not needed and add token_file=/app/redmine/config/email_oauth2
- ``rake redmine:email:receive_imap_oauth2 token_file=/app/redmine/config/email_oauth2 ...``
