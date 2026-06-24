import 'package:flutter/material.dart';

import 'login_page/login_page.dart';

class DashboardGuest extends StatefulWidget {
  const DashboardGuest({super.key});

  @override
  State<DashboardGuest> createState() =>
      _DashboardGuestState();
}

class _DashboardGuestState
    extends State<DashboardGuest> {

  /// ================= STATUS =================
  bool isExpanded = false;

  /// ================= MENU ITEM =================
  Widget menuItem(
      IconData icon,
      String title,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(vertical: 18),

      child: Row(
        children: [

          Icon(
            icon,
            size: 28,
            color: Colors.black87,
          ),

          const SizedBox(width: 20),

          Text(
            title,

            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F5F5),

      body: Stack(
          children: [

      /// ================= CONTENT =================
      SafeArea(
      child: Padding(
      padding:
      const EdgeInsets.all(20),

      child: Column(
        children: [

      /// ================= HEADER =================
      Row(
      children: [

      /// MENU BUTTON
      Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        boxShadow: [
          BoxShadow(
            blurRadius: 8,

            color: Colors.black
                .withOpacity(0.08),
          ),
        ],
      ),

      child: IconButton(
        onPressed: () {

          setState(() {
            isExpanded = true;
          });
        },

        icon: const Icon(
          Icons.menu,
          size: 32,
        ),
      ),
    ),

    const Spacer(),

    /// LOGO
    Row(
    children: const [

    Icon(
    Icons.air,
    color: Colors.blue,
    size: 40,
    ),

    SizedBox(width: 8),

    Text(
    "PureAir",

    style: TextStyle(
    fontSize: 28,
    fontWeight:
    FontWeight.bold,

    color: Colors.blue,
    ),
    ),
    ],
    ),

    const Spacer(),
    ],
    ),

    const SizedBox(height: 70),

    /// ================= GREETING =================
    const Text(
    "Good Morning 👋",

      style: TextStyle(
        fontSize: 30,
        fontStyle: FontStyle.italic,
      ),
    ),

          const SizedBox(height: 8),

          const Text(
            "Guest User",

            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 60),

          /// ================= SEARCH =================
          Container(
            height: 52,

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
              BorderRadius.circular(30),

              boxShadow: [
                BoxShadow(
                  blurRadius: 8,

                  color: Colors.black
                      .withOpacity(0.05),
                ),
              ],
            ),

            child: const TextField(
              decoration: InputDecoration(
                border: InputBorder.none,

                prefixIcon:
                Icon(Icons.search),

                hintText: "Cari Lokasi",
              ),
            ),
          ),

          const SizedBox(height: 30),

          /// ================= MAP =================
          Expanded(
            child: Container(
              width: double.infinity,

              decoration: BoxDecoration(
                color: Colors.grey.shade300,

                borderRadius:
                BorderRadius.circular(
                  25,
                ),
              ),

              child: const Center(
                child: Icon(
                  Icons.map,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
      ),

            /// ================= OVERLAY =================
            AnimatedOpacity(
              duration:
              const Duration(milliseconds: 300),

              opacity: isExpanded ? 1 : 0,

              child: isExpanded
                  ? GestureDetector(
                onTap: () {

                  setState(() {
                    isExpanded = false;
                  });
                },

                child: Container(
                  color: Colors.black
                      .withOpacity(0.4),
                ),
              )
                  : const SizedBox(),
            ),

            /// ================= SIDEBAR =================
            AnimatedPositioned(
              duration:
              const Duration(milliseconds: 300),

              curve: Curves.easeInOut,

              left: isExpanded ? 0 : -300,
              top: 0,
              bottom: 0,

              child: Container(
                width: 270,

                decoration: const BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight:
                    Radius.circular(30),
                  ),
                ),

                child: SafeArea(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 20,
                    ),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [

                        /// ================= CLOSE BUTTON =================
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,

                            borderRadius:
                            BorderRadius.circular(
                              15,
                            ),
                          ),

                          child: IconButton(
                            onPressed: () {

                              setState(() {
                                isExpanded = false;
                              });
                            },

                            icon: const Icon(
                              Icons.close,
                              size: 30,
                            ),
                          ),
                        ),

                        const SizedBox(height: 45),

                        /// ================= LOGO =================
                        Row(
                          children: const [

                            Icon(
                              Icons.air,
                              color: Colors.blue,
                              size: 42,
                            ),

                            SizedBox(width: 10),

                            Text(
                              "PureAir",

                              style: TextStyle(
                                fontSize: 26,
                                fontWeight:
                                FontWeight.bold,

                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        /// ================= MENU =================
                        menuItem(
                          Icons.dashboard_outlined,
                          "Dashboard",
                        ),

                        menuItem(
                          Icons.auto_graph,
                          "Prediksi",
                        ),

                        menuItem(
                          Icons.map_outlined,
                          "Map",
                        ),

                        menuItem(
                          Icons.info_outline,
                          "Tentang",
                        ),

                        const Spacer(),

                        /// ================= LOGIN BUTTON =================
                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton.icon(
                            onPressed: () {

                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                  const LoginPage(),
                                ),
                              );
                            },

                            style: ElevatedButton
                                .styleFrom(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                vertical: 15,
                              ),
                            ),

                            icon: const Icon(
                              Icons.login,
                            ),

                            label: const Text(
                              "Login",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }
}