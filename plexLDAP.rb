require 'net/ldap'
require 'yaml'
require 'logger'

require_relative 'plexTv.rb'

class PlexLDAP

	def initialize
		begin
    		config = YAML.load_file('config.yaml')
		rescue Errno::ENOENT => e
    		abort('Configuration file not found.  Exiting...')
		end

		begin
			$logger = Logger.new('plexldap.log')
		rescue Errno::ENOENT => e
			abort('Log file not found.  Exiting...')
		end

		$ldap = Net::LDAP.new
		$ldap.host = config['ldap']['server']
		$ldap.port = config['ldap']['port']
		$ldap.base = config['ldap']['base']
		$ldap.auth(config['ldap']['bind_user'], config['ldap']['bind_password'])

		begin
			$ldap.bind
		rescue Errno::ENOENT => e
			$logger.error('Cannot bind to LDAP server')
		end

		$plexTv = PlexTv.new(config)
	end

	def createUsers
		plex_users = $plexTv.get('/pms/friends/all')

		if plex_users.nil? || plex_users.empty?
			$logger.error("No Plex friends found.")  
		else                
    		plex_users['MediaContainer']['User'].each do | user |
				if user['username'] == 'Delightful Demon'
		    		dn = "cn=#{user['username']},ou=users,dc=felannisport,dc=com"
			    	attr = {
			        	:cn => user['username'],
	        	   		:givenname => user['username'],
    	       			:gidnumber => "501",
        	   			:homedirectory => "/home/users/#{user['username']}",
	        	   		:sn => user['username'],
    	       			:loginshell => "/sbin/nologin",
        	   			:objectClass => ["inetOrgPerson","posixAccount","top"],
	           			:uid => user['username'],
    	       			:mail => user['email'],
	    	       		:uidNumber => getNextUIDNumber.to_s,
				    }
					if $ldap.add(:dn => dn, :attributes => attr)
						$logger.info("Account #{user['username']} successfully added!")
					end
				end
			end
    	end
	end

	def getNextUIDNumber
		uidNumber = 0
		search_filter = Net::LDAP::Filter.eq('objectClass', 'inetOrgPerson')
		$ldap.search(:filter => search_filter, :return_result => false) do |entry|
			if entry['uidnumber'][0].to_i > uidNumber
				uidNumber = entry['uidnumber'][0].to_i
			end

			if uidNumber != 0
				return uidNumber += 1
			end
		end
	end
end

def main
	plexldap = PlexLDAP.new

	plexldap.createUsers
end

main()
