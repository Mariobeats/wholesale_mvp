import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/party_provider.dart';
import '../../widgets/party_card.dart';
import 'add_edit_party_screen.dart';

class PartiesScreen extends StatefulWidget {
  final bool isSelectionMode;

  const PartiesScreen({super.key, this.isSelectionMode = false});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PartyProvider>(context, listen: false).fetchParties();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, String partyId, String shopName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Party'),
          ],
        ),
        content: Text('Are you sure you want to delete party "$shopName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<PartyProvider>(context, listen: false);
              final success = await provider.deleteParty(partyId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Party deleted successfully' : 'Failed to delete party'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final partyProvider = Provider.of<PartyProvider>(context);
    final isAdmin = authProvider.isAdmin;
    final parties = partyProvider.filteredParties;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Party for Order' : 'Parties Directory'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Add Party', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditPartyScreen()),
          );
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => partyProvider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search shop name, owner or mobile...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          partyProvider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Parties List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => partyProvider.fetchParties(),
              child: partyProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : parties.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.store_outlined, size: 64, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Parties Found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Try searching or add a new party',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: parties.length,
                          itemBuilder: (context, index) {
                            final party = parties[index];
                            return PartyCard(
                              party: party,
                              isAdmin: isAdmin,
                              onTap: widget.isSelectionMode
                                  ? () => Navigator.pop(context, party)
                                  : null,
                              onEdit: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddEditPartyScreen(party: party),
                                  ),
                                );
                              },
                              onDelete: isAdmin ? () => _confirmDelete(context, party.id, party.shopName) : null,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
