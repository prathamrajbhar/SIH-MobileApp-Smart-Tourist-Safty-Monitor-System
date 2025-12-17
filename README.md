# SafeHorizon Tourist Safety App

A Flutter mobile application designed for tourist safety with real-time tracking, emergency features, and intelligent safety monitoring.

## Features

- **Real-time Location Tracking**: GPS monitoring with background service
- **Interactive Maps**: OpenStreetMap with heatmap visualization and geofencing
- **Safety Score System**: Dynamic 0-100 safety scoring based on location and context
- **Emergency SOS**: Instant panic button with location sharing to authorities
- **Proximity Alerts**: Notifications for nearby incidents and restricted zones
- **Safety Zones**: Real-time geofencing with warnings for restricted areas
- **Panic Button**: Emergency location sharing with authorities
- **Local Notifications**: Important safety alerts and updates
- **Modern UI**: Clean, accessible design with comprehensive safety features

## Quick Start

1. **Setup Environment**
   ```bash
   flutter pub get
   ```

2. **Configure Environment**
   - Copy `.env.example` to `.env`
   - Update API endpoints in `.env` file

3. **Run the App**
   ```bash
   flutter run
   ```

## Architecture

- **Models**: Data structures (Tourist, Location, Alert, etc.)
- **Services**: Business logic (API, Location, Geofencing, etc.)
- **Screens**: UI screens (Login, Home, Map, Profile)
- **Widgets**: Reusable components (Safety Score, Panic Button, etc.)
- **Theme**: Consistent design system and styling

## Documentation

- `API_DOCUMENTATION.md`: Complete API reference
- `ARCHITECTURE_DIAGRAM.md`: System architecture overview

## Technologies

- Flutter & Dart
- OpenStreetMap (flutter_map)
- Local Notifications
- JWT Authentication
- Real-time Location Services

---

**Built for Smart India Hackathon 2025**