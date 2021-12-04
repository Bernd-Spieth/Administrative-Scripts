# Reset-OwnersForUserProfiles
If a file share is set up to automatically create a roaming profile the first time a user logs on, Windows sets the person as the owner in the ACL. This can cause problems when the roaming profiles are moved to a new share on a different server, because the owner may be changed to a different account.

To make sure that the owner of the profile gets full access to his roaming profile folders again after the move, the script Reset-OwnersForProfiles.ps1 can be used. It iterates over a folder with roaming profiles and uses the name of the profile folder (which contains the user name) to determine the associated account in Active Directory and sets the ACL of the profile so that the Active Directory account is entered with full access to the profile.

Translated with www.DeepL.com/Translator (free version)
