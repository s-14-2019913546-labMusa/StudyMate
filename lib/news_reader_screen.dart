import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

class RssFeedItem {
  final String title;
  final String link;
  final String pubDate;
  final String description;

  RssFeedItem({required this.title, required this.link, required this.pubDate, required this.description});
}

class NewsReaderScreen extends StatefulWidget {
  const NewsReaderScreen({super.key});

  @override
  State<NewsReaderScreen> createState() => _NewsReaderScreenState();
}

class _NewsReaderScreenState extends State<NewsReaderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Default International and Local Feeds
  final List<Map<String, String>> _defaultFeeds = [
    {'name': 'BBC News', 'url': 'http://feeds.bbci.co.uk/news/world/rss.xml'},
    {'name': 'Al Jazeera', 'url': 'https://www.aljazeera.com/xml/rss/all.xml'},
    {'name': 'Prothom Alo', 'url': 'https://www.prothomalo.com/feed'},
    {'name': 'New York Times', 'url': 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml'},
    {'name': 'Daily Star', 'url': 'https://www.thedailystar.net/rss.xml'},
  ];

  Map<String, List<RssFeedItem>> _topHeadlines = {};
  bool _isLoadingHeadlines = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTopHeadlines();
  }

  Future<void> _loadTopHeadlines() async {
    setState(() => _isLoadingHeadlines = true);
    for (var feed in _defaultFeeds) {
      try {
        final items = await _fetchRss(feed['url']!);
        _topHeadlines[feed['name']!] = items;
      } catch (e) {
        _topHeadlines[feed['name']!] = [];
      }
    }
    if (mounted) setState(() => _isLoadingHeadlines = false);
  }

  Future<List<RssFeedItem>> _fetchRss(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final bodyStr = utf8.decode(response.bodyBytes, allowMalformed: true);
        final document = XmlDocument.parse(bodyStr);
        final items = document.findAllElements('item');
        return items.map((node) {
          return RssFeedItem(
            title: node.findElements('title').firstOrNull?.innerText ?? 'No Title',
            link: node.findElements('link').firstOrNull?.innerText ?? '',
            pubDate: node.findElements('pubDate').firstOrNull?.innerText ?? '',
            description: node.findElements('description').firstOrNull?.innerText ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching RSS: $e');
    }
    return [];
  }

  void _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildNewsList(List<RssFeedItem> items) {
    if (items.isEmpty) return const Center(child: Text("No news available from this source."));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length > 30 ? 30 : items.length, // Limit to 30 per feed
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openLink(item.link),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(item.pubDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeadlinesTab() {
    if (_isLoadingHeadlines) return const Center(child: CircularProgressIndicator());
    
    return DefaultTabController(
      length: _defaultFeeds.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabAlignment: TabAlignment.start,
            tabs: _defaultFeeds.map((f) => Tab(text: f['name'])).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: _defaultFeeds.map((f) {
                final items = _topHeadlines[f['name']] ?? [];
                return _buildNewsList(items);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyBookmarksTab() {
    if (currentUser == null) return const Center(child: Text("Please log in to use bookmarks."));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('custom_news_feeds').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddFeedDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Custom RSS Feed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
              ),
            ),
            if (docs.isEmpty)
              const Expanded(child: Center(child: Text("No custom feeds added yet.\nTry adding a news RSS link!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))),
            if (docs.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text(data['name'] ?? 'Unnamed Feed', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['url'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        children: [
                          FutureBuilder<List<RssFeedItem>>(
                            future: _fetchRss(data['url']),
                            builder: (context, futureSnapshot) {
                              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                              }
                              final items = futureSnapshot.data ?? [];
                              if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("Could not load feed. Check URL."));
                              
                              return SizedBox(
                                height: 350,
                                child: _buildNewsList(items),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TextButton.icon(
                              onPressed: () {
                                FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('custom_news_feeds').doc(docId).delete();
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text('Delete Feed', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddFeedDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add RSS Feed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Feed Name (e.g. Prothom Alo)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'RSS URL', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('custom_news_feeds').add({
                    'name': nameCtrl.text.trim(),
                    'url': urlCtrl.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feed added successfully!')));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add feed. Check Firebase rules.')));
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily News', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.public), text: 'Top Headlines'),
            Tab(icon: Icon(Icons.bookmark), text: 'My Bookmarks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTopHeadlinesTab(),
          _buildMyBookmarksTab(),
        ],
      ),
    );
  }
}
