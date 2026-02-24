import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: GasolineProCalculator(),
    ));

class GasolineProCalculator extends StatefulWidget {
  @override
  _GasolineProCalculatorState createState() => _GasolineProCalculatorState();
}

class _GasolineProCalculatorState extends State<GasolineProCalculator> {
  final int rowCount = 8; // تحدد لـ 8 صفوف بناءً على طلبك
  late List<Map<String, TextEditingController>> rowsData;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String productGrade = "95"; 

  double totalLevel = 0.0, ethyl135 = 0.0, finalDen = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalRvp = 0.0, finalOle = 0.0, finalS = 0.0, finalSens = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    rowsData = List.generate(rowCount, (index) {
      var row = <String, TextEditingController>{};
      ['tank', 'prod', 'level', 'oct', 'sens', 'den', 'ar', 'ben', 'ole', 'rvp', 's']
          .forEach((key) {
        row[key] = TextEditingController(text: (key == 'tank' || key == 'prod') ? '' : '0');
        row[key]!.addListener(() {
          _saveData(index, key, row[key]!.text);
          _calculateAll();
        });
      });
      return row;
    });
    _loadSavedData();
  }

  _saveData(int index, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('row_${index}_$key', value);
  }

  _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount; i++) {
      rowsData[i].forEach((key, controller) {
        controller.text = prefs.getString('row_${i}_$key') ?? controller.text;
      });
    }
    _calculateAll();
  }

  void _calculateAll() {
    double tLvl = 0, wOct = 0, wSens = 0, wDen = 0, wAr = 0, wBen = 0, wOle = 0, wS = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var r in rowsData) tLvl += double.tryParse(r["level"]!.text) ?? 0;

    if (tLvl > 0) {
      for (var r in rowsData) {
        double l = double.tryParse(r["level"]!.text) ?? 0;
        double ratio = l / tLvl;
        wOct += ratio * (double.tryParse(r["oct"]!.text) ?? 0);
        wSens += ratio * (double.tryParse(r["sens"]!.text) ?? 0);
        wDen += ratio * (double.tryParse(r["den"]!.text) ?? 0);
        wAr += ratio * (double.tryParse(r["ar"]!.text) ?? 0);
        wBen += ratio * (double.tryParse(r["ben"]!.text) ?? 0);
        wOle += ratio * (double.tryParse(r["ole"]!.text) ?? 0);
        wS += ratio * (double.tryParse(r["s"]!.text) ?? 0);
        sumRJ += ratio * (double.tryParse(r["oct"]!.text) ?? 0) * (double.tryParse(r["sens"]!.text) ?? 0);
        sumO2 += ratio * pow((double.tryParse(r["ole"]!.text) ?? 0), 2);
        double rvp = double.tryParse(r["rvp"]!.text) ?? 0;
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      ethyl135 = wOct + (0.03324 * (sumRJ - (wOct * wSens))) + (0.00085 * (sumO2 - pow(wOle, 2)));
    }

    setState(() {
      totalLevel = tLvl; finalSens = wSens; finalDen = wDen;
      finalAr = wAr; finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Text("Gasoline Blending Calculator", style: TextStyle(fontSize: 16)),
        actions: [
          DropdownButton<String>(
            value: productGrade,
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("Grade $s "))).toList(),
            onChanged: (v) => setState(() => productGrade = v!),
          ),
          IconButton(icon: Icon(Icons.photo_camera, color: Colors.greenAccent), onPressed: _showRecipeDialog),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // الجزء الأول: جدول المدخلات
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 12,
                        headingRowHeight: 40,
                        dataRowHeight: 38,
                        headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                        border: TableBorder.all(color: Colors.grey[700]!),
                        columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Den', 'Ar%', 'Ben%', 'RVP']
                            .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                        rows: rowsData.map((row) => DataRow(cells: [
                          _inputCell(row['tank']!, 50, true), _inputCell(row['prod']!, 65, true),
                          _inputCell(row['level']!, 50, false), _inputCell(row['oct']!, 40, false),
                          _inputCell(row['sens']!, 40, false), _inputCell(row['den']!, 60, false),
                          _inputCell(row['ar']!, 40, false), _inputCell(row['ben']!, 40, false),
                          _inputCell(row['rvp']!, 45, false),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              // الجزء الثاني: لوحة النتائج النهائية (The Final Dashboard)
              _buildFinalResultsDashboard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFinalResultsDashboard() {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text("FINAL BLEND SPECIFICATION", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultItem("TOTAL LVL", totalLevel.toStringAsFixed(1), Colors.white),
              _resultItem("ETHYL OCT", ethyl135.toStringAsFixed(2), Colors.greenAccent, isSpec: true, type: "OCT"),
              _resultItem("DENSITY", finalDen.toStringAsFixed(4), Colors.cyanAccent),
            ],
          ),
          Divider(color: Colors.grey[700]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultItem("AROMATICS", finalAr.toStringAsFixed(1), Colors.white, isSpec: true, type: "AR"),
              _resultItem("BENZENE", finalBen.toStringAsFixed(2), Colors.white, isSpec: true, type: "BEN"),
              _resultItem("RVP", finalRvp.toStringAsFixed(2), Colors.purpleAccent, isSpec: true, type: "RVP"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultItem(String label, String value, Color color, {bool isSpec = false, String type = ""}) {
    Color displayColor = color;
    if (isSpec) {
      displayColor = _getSpecColor(type, double.tryParse(value) ?? 0);
    }
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 9)),
        Text(value, style: TextStyle(color: displayColor, fontSize: 16, fontWeight: FontWeight.black)),
      ],
    );
  }

  Color _getSpecColor(String type, double val) {
    if (productGrade == "95") {
      if (type == "OCT") return val >= 95 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 33 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 0.9 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= 0.7 ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return val >= 92 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 35 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
    }
    return Colors.white;
  }

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, 
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11),
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(border: InputBorder.none),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Gasoline Blending Recipe", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blue, fontSize: 12)),
              Divider(),
              _recipeTable(),
              Divider(),
              _recipeRow("ETHYL OCTANE:", ethyl135.toStringAsFixed(2)),
              _recipeRow("TOTAL LEVEL:", totalLevel.toStringAsFixed(1)),
              _recipeRow("FINAL RVP:", finalRvp.toStringAsFixed(2)),
            ],
          ),
        ),
      ),
      actions: [ElevatedButton(onPressed: _saveImg, child: Text("Save to Gallery"))],
    ));
  }

  Widget _recipeTable() {
    return Table(
      border: TableBorder.all(color: Colors.black12),
      children: [
        TableRow(children: [_th("Tank"), _th("Level"), _th("Oct")]),
        ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
          children: [_td(r['tank']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
        )).toList()
      ],
    );
  }

  Widget _th(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 10), textAlign: TextAlign.center));

  Widget _recipeRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black, fontSize: 11)), Text(v, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))]);

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
    }
  }
}
