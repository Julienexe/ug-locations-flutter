import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ug_locations/ug_locations.dart';

void main() {
  // Desktop platforms need the FFI-based sqflite implementation; Android/iOS
  // work out of the box with the default sqflite plugin.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const UgLocationsExampleApp());
}

class UgLocationsExampleApp extends StatelessWidget {
  const UgLocationsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ug_locations example',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UgandaLocations? _ug;
  List<UgandaLocation> _searchResults = <UgandaLocation>[];

  List<String> _districts = <String>[];
  List<String> _subcounties = <String>[];
  List<String> _parishes = <String>[];
  List<String> _villages = <String>[];

  String? _selectedDistrict;
  String? _selectedSubcounty;
  String? _selectedParish;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ug = await UgandaLocations.getInstance();
    final districts = await ug.getDistricts();
    setState(() {
      _ug = ug;
      _districts = districts;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    final ug = _ug;
    if (ug == null || query.trim().isEmpty) {
      setState(() => _searchResults = <UgandaLocation>[]);
      return;
    }
    final results = await ug.search(query, limit: 20);
    setState(() => _searchResults = results);
  }

  Future<void> _onDistrictSelected(String? district) async {
    final ug = _ug;
    setState(() {
      _selectedDistrict = district;
      _selectedSubcounty = null;
      _selectedParish = null;
      _subcounties = <String>[];
      _parishes = <String>[];
      _villages = <String>[];
    });
    if (ug == null || district == null) return;
    final subcounties = await ug.getSubcountiesInDistrict(district);
    setState(() => _subcounties = subcounties);
  }

  Future<void> _onSubcountySelected(String? subcounty) async {
    final ug = _ug;
    setState(() {
      _selectedSubcounty = subcounty;
      _selectedParish = null;
      _parishes = <String>[];
      _villages = <String>[];
    });
    if (ug == null || subcounty == null || _selectedDistrict == null) return;
    final parishes = await ug.getParishesInSubcounty(_selectedDistrict!, subcounty);
    setState(() => _parishes = parishes);
  }

  Future<void> _onParishSelected(String? parish) async {
    final ug = _ug;
    setState(() {
      _selectedParish = parish;
      _villages = <String>[];
    });
    if (ug == null ||
        parish == null ||
        _selectedDistrict == null ||
        _selectedSubcounty == null) {
      return;
    }
    final villages = await ug.getVillagesInParish(
      _selectedDistrict!,
      _selectedSubcounty!,
      parish,
    );
    setState(() => _villages = villages);
  }

  @override
  Widget build(BuildContext context) {
    if (_ug == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ug_locations example')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Search'), Tab(text: 'Cascading selector')]),
            Expanded(
              child: TabBarView(
                children: [_buildSearchTab(), _buildSelectorTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search village / parish / subcounty / district',
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final loc = _searchResults[index];
                return ListTile(
                  title: Text(loc.village),
                  subtitle: Text('${loc.parish} → ${loc.subcounty} → ${loc.district}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDistrict,
            decoration: const InputDecoration(labelText: 'District'),
            items: [
              for (final d in _districts.toSet())
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: _onDistrictSelected,
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubcounty,
            decoration: const InputDecoration(labelText: 'Subcounty'),
            items: [
              for (final s in _subcounties.toSet())
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: _subcounties.isEmpty ? null : _onSubcountySelected,
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedParish,
            decoration: const InputDecoration(labelText: 'Parish'),
            items: [
              // Source data can list the same parish name more than once
              // within a subcounty (e.g. ARUA / ARIVU has two entries) -
              // dedupe since dropdown items must have unique values.
              for (final p in _parishes.toSet())
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: _parishes.isEmpty ? null : _onParishSelected,
          ),
          const SizedBox(height: 16),
          Text('Villages (${_villages.length})', style: Theme.of(context).textTheme.titleMedium),
          Expanded(
            child: ListView.builder(
              itemCount: _villages.length,
              itemBuilder: (context, index) => ListTile(title: Text(_villages[index])),
            ),
          ),
        ],
      ),
    );
  }
}
