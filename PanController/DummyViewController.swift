//
//  DummyViewController.swift
//  PanController
//

import UIKit

class DummyViewController: UIViewController, PanControllerChildren {

    @IBOutlet weak var label: UILabel!
    var number: Int = 0 {
        didSet {
            label.text = "\(number)"
        }
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    convenience init() {
        self.init(nibName: "DummyViewController", bundle: nil)
    }
    
    convenience init(_ number: Int) {
        self.init()
        self.number = number
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "\(number)"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        print("ViewController \(number) will appear.")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        print("ViewController \(number) did appear.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        print("ViewController \(number) will disappear.")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        print("ViewController \(number) did disappear.")
    }

    func viewWillEnter(withPanController panController: PanController, from: PanController.Direction) {
        print("ViewController[\(number)] viewWillEnter from \(from)")
    }
    func viewWillOut(withPanController panController: PanController, to: PanController.Direction) {
        print("ViewController[\(number)] viewWillOut to \(to)")
    }
    func viewDidEnter(withPanController panController: PanController, from: PanController.Direction) {
        print("ViewController[\(number)] viewDidEnter from \(from)")
    }
    func viewDidOut(withPanController panController: PanController, to: PanController.Direction) {
        print("ViewController[\(number)] viewDidOut to \(to)")
    }

}


extension DummyViewController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
 
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell")
        
        cell?.textLabel?.text = "ROW \(indexPath.row)"
        
        return cell ?? UITableViewCell()
        
    }

}

