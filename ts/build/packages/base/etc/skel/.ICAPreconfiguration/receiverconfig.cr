<?xml version="1.0" encoding="utf-8"?>
<Services version="1.0" xmlns="http://www.citrix.com/ServiceRecord">

	<Service type="store">
		<SRID>619165696</SRID>
		<Name>MyWorkSpaceJPMCStore</Name>
		<Address>https://myworkspace.jpmchase.net/Citrix/JPMCStore/discovery</Address>
		
		<Gateways>
			<Gateway Name="SNACARICCAG03V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
			<Gateway Name="SNACARICCAG04V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
			<Gateway Name="SNACD2ICCAG01V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
			<Gateway Name="SNACD2ICCAG02V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
			<Gateway Name="SNARDCICCAG01V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
			<Gateway Name="SNARDCICCAG02V01" Edition="Enterprise" Auth="DomainAndRSA" RewriteMode="NONE">
				<Location>https://myworkspace.jpmchase.com/</Location>
			</Gateway>
		</Gateways>
		
		<Beacons>
			<Internal>
				<Beacon>https://myworkspace.jpmchase.net/</Beacon>
			</Internal>
			<External>
				<Beacon>https://myworkspace.jpmchase.com/</Beacon>
				<Beacon>http://ping.citrix.com</Beacon>
			</External>
		</Beacons>
		
	</Service>

</Services>
