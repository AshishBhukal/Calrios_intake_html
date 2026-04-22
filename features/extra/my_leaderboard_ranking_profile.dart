import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitness2/features/extra/add_proof.dart';
import 'package:fitness2/features/extra/yt_video_widget.dart';
import 'package:fitness2/features/extra/constants.dart';
import 'package:fitness2/services/unit_preference_service.dart';

class MyLeaderboardRankingProfile extends StatefulWidget {
  final String userId;
  final int exerciseId;
  final String exercise;
  final int rank;
  final double weight;
  final String monthKey;
  final String ageGroup;
  final String gender;

  const MyLeaderboardRankingProfile({
    super.key,
    required this.userId,
    required this.exerciseId,
    required this.exercise,
    required this.rank,
    required this.weight,
    required this.monthKey,
    required this.ageGroup,
    required this.gender,
  });

  @override
  _MyLeaderboardRankingProfileState createState() => _MyLeaderboardRankingProfileState();
  
  // Generate composite key for proof storage
  String get compositeKey => '${exerciseId}_${monthKey}_$userId';
}

class _MyLeaderboardRankingProfileState extends State<MyLeaderboardRankingProfile> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _userWeightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadUserWeightUnit();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  Future<void> _loadUserWeightUnit() async {
    final unit = await UnitPreferenceService.getWeightUnit();
    if (mounted) {
      setState(() {
        _userWeightUnit = unit;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _fetchProofs() {
    return _firestore
        .collection('leaderboardProofs')
        .doc(widget.compositeKey)
        .collection('proofs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildGradientText(String text, TextStyle baseStyle) {
    return ShaderMask(
      shaderCallback: (bounds) => DesignSystem.textGradient.createShader(bounds),
      child: Text(
        text,
        style: baseStyle.copyWith(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: _buildModernAppBar(),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false, // Allow content behind Dynamic Island
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.all(DesignSystem.spacing16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: DesignSystem.spacing16.rh),
                      _buildRankCard(),
                      SizedBox(height: DesignSystem.spacing24.rh),
                      _buildAddProofButton(),
                      SizedBox(height: DesignSystem.spacing32.rh),
                      _buildProofsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: DesignSystem.appBarGradient,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: DesignSystem.light,
          size: 28,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Ranking Details',
        style: DesignSystem.titleMedium.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildRankCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: DesignSystem.glassBg,
        borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
        border: Border.all(color: DesignSystem.glassBorder, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
          gradient: DesignSystem.cardGradient,
        ),
        child: Padding(
          padding: EdgeInsets.all(DesignSystem.spacing24.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Rank',
                style: DesignSystem.labelMedium,
              ),
              const SizedBox(height: DesignSystem.spacing4),
              _buildGradientText(
                '#${widget.rank}',
                DesignSystem.headlineLarge,
              ),
              SizedBox(height: DesignSystem.spacing24.rh),
              _buildStatRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow() {
    // Convert weight from kg (stored in Firebase) to user's preferred unit
    final displayWeight = UnitConverter.convertWeightFromKg(widget.weight, _userWeightUnit);
    final formattedWeight = UnitConverter.formatWeight(displayWeight, _userWeightUnit);
    
    return Row(
      children: [
        Expanded(
          child: _buildStatItem('Exercise', widget.exercise),
        ),
        SizedBox(width: DesignSystem.spacing16.rw),
        Expanded(
          child: _buildStatItem('Weight', formattedWeight),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DesignSystem.labelMedium,
        ),
        const SizedBox(height: DesignSystem.spacing4),
        Text(
          value,
          style: DesignSystem.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddProofButton() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: DesignSystem.primaryGradient,
          borderRadius: BorderRadius.circular(DesignSystem.buttonRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(DesignSystem.buttonRadius),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProofScreen(compositeKey: widget.compositeKey),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: DesignSystem.spacing32.rw,
                vertical: DesignSystem.spacing16.rh,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: DesignSystem.light,
                    size: 24,
                  ),
                  const SizedBox(width: DesignSystem.spacing8),
                  Text(
                    'Add Proof',
                    style: DesignSystem.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProofsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: DesignSystem.light,
              size: 24,
            ),
            const SizedBox(width: DesignSystem.spacing8),
            Text(
              'Your Proofs',
              style: DesignSystem.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: DesignSystem.spacing16.rh),
        StreamBuilder<QuerySnapshot>(
          stream: _fetchProofs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => SizedBox(height: DesignSystem.spacing16.rh),
              itemBuilder: (context, index) {
                final proof = snapshot.data!.docs[index];
                final proofData = proof.data() as Map<String, dynamic>?;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      0.3 + (index * 0.1),
                      0.8 + (index * 0.1),
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: ProofItem(
                    videoUrl: proofData?['proofVideoUrl'], // Only use Firebase Storage proofs
                    comment: proofData?['comment'],
                    proofStatus: proofData?['proofStatus'] ?? 'ready', // Default to ready for legacy
                    errorMessage: proofData?['errorMessage'],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.glassBg,
        borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
        border: Border.all(color: DesignSystem.glassBorder, width: 1),
      ),
      padding: EdgeInsets.all(DesignSystem.spacing32.r),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: DesignSystem.light,
              strokeWidth: 2,
            ),
            SizedBox(height: DesignSystem.spacing16.rh),
            const Text(
              'Loading proofs...',
              style: DesignSystem.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.glassBg,
        borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
        border: Border.all(
          color: DesignSystem.glassBorder,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      padding: EdgeInsets.all(DesignSystem.spacing32.r),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              size: 48,
              color: DesignSystem.mediumGray,
            ),
            SizedBox(height: DesignSystem.spacing16.rh),
            const Text(
              'No proofs found. Add your first proof!',
              style: DesignSystem.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ProofItem extends StatelessWidget {
  final String? videoUrl;
  final String? comment;
  final String proofStatus;
  final String? errorMessage;

  const ProofItem({
    super.key,
    this.videoUrl,
    this.comment,
    this.proofStatus = 'ready',
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.glassBg,
        borderRadius: BorderRadius.circular(DesignSystem.cardRadius),
        border: Border.all(color: DesignSystem.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(DesignSystem.cardRadius),
              topRight: Radius.circular(DesignSystem.cardRadius),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _buildVideoContent(),
              ),
            ),
          ),
          if (comment != null && comment!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(DesignSystem.spacing16.r),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.2),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(DesignSystem.cardRadius),
                  bottomRight: Radius.circular(DesignSystem.cardRadius),
                ),
                border: Border(
                  top: BorderSide(
                    color: DesignSystem.glassBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comment',
                    style: DesignSystem.labelSmall,
                  ),
                  const SizedBox(height: DesignSystem.spacing8),
                  Text(
                    comment!,
                    style: DesignSystem.bodyMedium.copyWith(
                      color: DesignSystem.lightGray,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    switch (proofStatus) {
      case 'uploading':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: DesignSystem.primary,
                strokeWidth: 2,
              ),
              SizedBox(height: DesignSystem.spacing12.rh),
              const Text(
                'Uploading video...',
                style: DesignSystem.bodyMedium,
              ),
            ],
          ),
        );
      case 'processing':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: DesignSystem.primary,
                strokeWidth: 2,
              ),
              SizedBox(height: DesignSystem.spacing12.rh),
              const Text(
                'Optimizing video...',
                style: DesignSystem.bodyMedium,
              ),
              const SizedBox(height: DesignSystem.spacing4),
              const Text(
                'This may take a few minutes',
                style: DesignSystem.labelSmall,
              ),
            ],
          ),
        );
      case 'failed':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              SizedBox(height: DesignSystem.spacing12.rh),
              const Text(
                'Processing failed',
                style: DesignSystem.bodyMedium,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: DesignSystem.spacing8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: DesignSystem.spacing16.rw),
                  child: Text(
                    errorMessage!,
                    style: DesignSystem.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      case 'ready':
      default:
        if (videoUrl != null && videoUrl!.isNotEmpty) {
          return YTVideoWidget(videoUrl: videoUrl);
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: DesignSystem.mediumGray,
                  size: 48,
                ),
                SizedBox(height: DesignSystem.spacing12.rh),
                const Text(
                  'Video not available',
                  style: DesignSystem.labelMedium,
                ),
              ],
            ),
          );
        }
    }
  }
}
