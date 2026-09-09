import 'package:flutter/material.dart';

import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';

/// The entire pill is a tap target, including the small plus symbol.
class PointsBalanceButton extends StatelessWidget {
  final int points;
  final VoidCallback onPressed;

  const PointsBalanceButton({
    super.key,
    required this.points,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '點數餘額 $points 點，查看點數與會員方案',
      excludeSemantics: true,
      child: Tooltip(
        message: '點數與會員方案',
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          child: InkWell(
            key: const Key('open-points-shop'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pets_rounded,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$points PT',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preview only: store products and server-side credit fulfillment are pending.
/// Selecting an offer must never change credits or membership entitlements.
class PointsShopScreen extends StatefulWidget {
  final Stream<UserModel?> userStream;
  final String initialOffer;

  const PointsShopScreen({
    super.key,
    required this.userStream,
    this.initialOffer = 'points10',
  });

  static void open(BuildContext context, {String initialOffer = 'points10'}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointsShopScreen(
          userStream: getIt<AuthService>().getUserStream(),
          initialOffer: initialOffer,
        ),
      ),
    );
  }

  @override
  State<PointsShopScreen> createState() => _PointsShopScreenState();
}

class _Offer {
  final String id;
  final String name;
  final String price;
  final String cadence;
  final String description;
  final List<String> benefits;

  const _Offer(
    this.id,
    this.name,
    this.price,
    this.cadence,
    this.description,
    this.benefits,
  );
}

class _PointsShopScreenState extends State<PointsShopScreen> {
  static const _offers = [
    _Offer('points10', '10 點體驗包', 'NT\$49', '／一次購買', '偶爾想聊聊，按需要補充點數。', [
      '10 點可進行 10 次完整溝通',
      '購買點數不隨每日額度重置',
      '不含會員升級或免廣告權益',
    ]),
    _Offer('free', 'Free', 'NT\$0', '／免費', '先從每天一次的陪伴開始。', [
      '每日 1 點，當日有效、不累積',
      '含廣告；新資料儲存於本機',
      '獎勵廣告換點尚未開放',
    ]),
    _Offer('plus', 'Plus', 'NT\$199', '／月', '適合經常想了解毛孩的你。', [
      '每日 5 點，當日有效、不累積',
      '無廣告體驗',
      '毛孩資料雲端同步',
    ]),
    _Offer('pro', 'Pro', 'NT\$399', '／月', '更充裕的額度，陪伴更多日常。', [
      '每訂閱期 600 次，每日最多 30 次',
      '額度按訂閱週期重置，不跨期累積',
      '無廣告體驗與毛孩資料雲端同步',
    ]),
  ];

  late String _selected;
  late bool _showMemberships;

  @override
  void initState() {
    super.initState();
    _selected = _offers.any((offer) => offer.id == widget.initialOffer)
        ? widget.initialOffer
        : 'points10';
    _showMemberships = _selected != 'points10';
  }

  _Offer get _offer => _offers.firstWhere((offer) => offer.id == _selected);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFB),
      appBar: AppBar(
        title: const Text('點數與會員方案'),
        backgroundColor: const Color(0xFFF5FAFB),
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<UserModel?>(
                    stream: widget.userStream,
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.backgroundGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '讓每一次陪伴，多一點理解',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (user != null)
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text('目前餘額  ${user.points} PT'),
                                  Text(
                                    '目前會員  ${user.membershipTier.toUpperCase()}',
                                  ),
                                ],
                              )
                            else
                              Text(
                                snapshot.hasError
                                    ? '暫時無法讀取餘額，仍可瀏覽方案。'
                                    : snapshot.connectionState ==
                                          ConnectionState.waiting
                                    ? '正在讀取會員資料…'
                                    : '登入後可查看點數與目前會員。',
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '方案預覽・尚未開放購買\n目前 AI 溝通暫不扣點。以下價格、每日贈點與用量為預定方案，尚未生效；選擇方案不會扣款或變更會員。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('購買點數'),
                        icon: Icon(Icons.pets_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('會員方案'),
                        icon: Icon(Icons.workspace_premium_outlined),
                      ),
                    ],
                    selected: {_showMemberships},
                    onSelectionChanged: (values) => setState(() {
                      _showMemberships = values.single;
                      _selected = _showMemberships ? 'plus' : 'points10';
                    }),
                  ),
                  const SizedBox(height: 20),
                  for (final offer in _offers.where(
                    (offer) => _showMemberships
                        ? offer.id != 'points10'
                        : offer.id == 'points10',
                  ))
                    _offerCard(offer),
                  const SizedBox(height: 4),
                  const Text(
                    '各方案提供相同的 AI 溝通模型，依額度、廣告與雲端功能區分。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('點數怎麼使用？'),
                    childrenPadding: EdgeInsets.only(bottom: 16),
                    children: [
                      Text(
                        '正式開放後：\n'
                        '• 1 點＝1 次完整溝通，一次最多 5 題。\n'
                        '• 成功取得結果才扣點；失敗、讀取舊結果不重扣。\n'
                        '• 修改資料後重新生成，算新的一次。\n'
                        '• 優先使用每日贈點，再扣購買點數。\n'
                        '• 每日贈點於台灣時間 00:00 重置；購買點數保留至用完。',
                        style: TextStyle(
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '正式購買將於 Android 版透過 Google Play 完成，價格以商店結帳畫面為準。月訂閱自動續訂，可於 Google Play 管理或取消；購買點數為單次付款，不自動續購。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '已選擇 ${_offer.name} · ${_offer.price}${_offer.cadence}',
                key: const Key('selected-offer'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  child: Text(_selected == 'free' ? '免費方案免購買' : '尚未開放購買'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offerCard(_Offer offer) {
    final selected = _selected == offer.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? const Color(0xFFEDF7F5) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? AppColors.secondary : const Color(0xFFE1E9ED),
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('offer-${offer.id}'),
            onTap: () => setState(() => _selected = offer.id),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: offer.price,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: offer.cadence,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.description,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  for (final benefit in offer.benefits)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
