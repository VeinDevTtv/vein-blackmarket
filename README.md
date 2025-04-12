# Black Market Courier System

A shadowy underworld job system for FiveM servers with encrypted communication, burner phones, and high-risk delivery missions.

## Features

🔥 **Black Market Courier System**
- Underground delivery job with encrypted communication and police evasion mechanics
- Risk vs. reward system with increasing difficulty levels and payouts
- Dynamic reputation system that unlocks harder missions and better rewards

📱 **Burner Phone App**
- Custom UI with glitchy, encrypted messaging system
- Messages decrypt in real-time with animation effects
- Self-destruct feature to wipe evidence
- Contract management system

📦 **Dynamic Contract Generator**
- Random contracts with various difficulty levels
- Unique pickup and drop-off locations based on difficulty
- Bonus items for higher-risk deliveries
- Decoy package system for added challenge

🚨 **Police Awareness System**
- Heat level increases with reckless driving, staying too long in one place, or drawing weapons
- Police alerts when heat gets too high
- Stealth delivery bonuses for staying under the radar

👥 **Reputation and Rank**
- Progress through reputation levels to unlock better contracts
- Higher rep grants access to more lucrative and challenging deliveries
- Special rewards for high-level couriers

🧊 **World Immersion**
- NPC watchers that follow high-risk deliveries
- Random ambient events during deliveries
- Environmental awareness mechanics

## Installation

1. Add the `vein-blackmarket` folder to your server's resources directory
2. Add `start vein-blackmarket` to your server.cfg
3. Ensure you have qb-core installed and running
4. Add the burner phone image to your inventory resource (if needed)
5. Restart your server

## Configuration

You can customize the script by editing the `config/config.lua` file:

- Change contract difficulties and payouts
- Add or modify pickup/dropoff locations
- Adjust the police awareness system sensitivity
- Configure reputation levels and rewards
- Customize the burner phone item properties

## Usage

### Player Instructions
1. Purchase a burner phone from the dealer (located at coords in config)
2. Wait for contract messages to arrive
3. Accept contracts through the burner phone app
4. Navigate to pickup location and collect the package
5. Deliver to the drop-off location while avoiding police attention
6. Complete deliveries to earn money and build reputation

### Admin Commands
- `/blackmarket_debug` - Shows current state of the black market system (debug mode only)

## Dependencies

- QBCore Framework
- Latest FiveM build

## Credits

Created by Vein

## License

This resource is protected under copyright law. You are free to use and modify it for your server, but redistribution or resale is strictly prohibited without permission.

## Support

For support or feature requests, contact us through our Discord: discord.gg/evolve