//
//  RootViewController.swift
//  SimpleEKDemo
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/6/30.
//
//
/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Table view controller that displays events occuring within the next 24 hours. Prompts a user for access to their Calendar, then updates its UI according to their response.
*/

import UIKit
import EventKit
import EventKitUI

@objc(RootViewController)
class RootViewController: UITableViewController, EKEventEditViewDelegate {
    // EKEventStore instance associated with the current Calendar application
    var eventStore: EKEventStore!
    
    // Default calendar associated with the above event store
    var defaultCalendar: EKCalendar!
    
    // Array of all events happening within the next 24 hours
    var eventsList: [EKEvent] = []
    
    // Used to add events to Calendar
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    
    //MARK: -
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize the event store
        self.eventStore = EKEventStore()
        // Initialize the events list
        // The Add button is initially disabled
        self.addButton.enabled = false
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // Check whether we are authorized to access Calendar
        self.checkEventStoreAccessForCalendar()
    }
    
    
    // This method is called when the user selects an event in the table view. It configures the destination
    // event view controller with this event.
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showEventViewController" {
            // Configure the destination event view controller
            let eventViewController = segue.destinationViewController as! EKEventViewController
            // Fetch the index path associated with the selected event
            let indexPath = self.tableView.indexPathForSelectedRow!
            // Set the view controller to display the selected event
            eventViewController.event = self.eventsList[indexPath.row]
            
            // Allow event editing
            eventViewController.allowsEditing = true
        }
    }
    
    
    //MARK: -
    //MARK: Table View
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.eventsList.count
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("eventCell", forIndexPath: indexPath)
        
        // Get the event at the row selected and display its title
        cell.textLabel!.text = self.eventsList[indexPath.row].title
        return cell
    }
    
    
    //MARK: -
    //MARK: Access Calendar
    
    // Check the authorization status of our application for Calendar
    private func checkEventStoreAccessForCalendar() {
        let status = EKEventStore.authorizationStatusForEntityType(EKEntityType.Event)
        
        switch status {
            // Update our UI if the user has granted access to their Calendar
        case .Authorized: self.accessGrantedForCalendar()
            // Prompt the user for access to Calendar if there is no definitive answer
        case .NotDetermined: self.requestCalendarAccess()
            // Display a message if the user has denied or restricted access to Calendar
        case .Denied, .Restricted:
            if #available(iOS 8.0, *) {
                let alertController = UIAlertController(title: "Privacy Warning", message: "Permission was not granted for Calendar", preferredStyle: .Alert)
                let defaultAction = UIAlertAction(title: "OK", style: .Cancel, handler: {action in})
                alertController.addAction(defaultAction)
                self.presentViewController(alertController, animated: true, completion: nil)
            } else {
                let alert = UIAlertView(title: "Privacy Warning", message: "Permission was not granted for Calendar",
                    delegate: nil,
                    cancelButtonTitle: "OK")
                alert.show()
            }
        }
    }
    
    
    // Prompt the user for access to their Calendar
    private func requestCalendarAccess() {
        self.eventStore.requestAccessToEntityType(.Event) {[weak self] granted, error in
            if granted {
                // Let's ensure that our code will be executed from the main queue
                dispatch_async(dispatch_get_main_queue()) {
                    // The user has granted access to their Calendar; let's populate our UI with all events occuring in the next 24 hours.
                    self?.accessGrantedForCalendar()
                }
            }
        }
    }
    
    
    // This method is called when the user has granted permission to Calendar
    private func accessGrantedForCalendar() {
        // Let's get the default calendar associated with our event store
        self.defaultCalendar = self.eventStore.defaultCalendarForNewEvents
        // Enable the Add button
        self.addButton.enabled = true
        // Fetch all events happening in the next 24 hours and put them into eventsList
        self.eventsList = self.fetchEvents()
        // Update the UI with the above events
        self.tableView.reloadData()
    }
    
    
    //MARK: -
    //MARK: Fetch events
    
    // Fetch all events happening in the next 24 hours
    private func fetchEvents() -> [EKEvent] {
        let startDate = NSDate()
        
        //Create the end date components
        let tomorrowDateComponents = NSDateComponents()
        tomorrowDateComponents.day = 1
        
        let endDate = NSCalendar.currentCalendar().dateByAddingComponents(tomorrowDateComponents,
            toDate: startDate,
            options: [])!
        // We will only search the default calendar for our events
        let calendarArray: [EKCalendar] = [self.defaultCalendar]
        
        // Create the predicate
        let predicate = self.eventStore.predicateForEventsWithStartDate(startDate,
            endDate: endDate,
            calendars: calendarArray)
        
        // Fetch all events that match the predicate
        let events = self.eventStore.eventsMatchingPredicate(predicate)
        
        return events
    }
    
    
    //MARK: -
    //MARK: Add a new event
    
    // Display an event edit view controller when the user taps the "+" button.
    // A new event is added to Calendar when the user taps the "Done" button in the above view controller.
    @IBAction func addEvent(_: AnyObject) {
        // Create an instance of EKEventEditViewController
        let addController = EKEventEditViewController()
        
        // Set addController's event store to the current event store
        addController.eventStore = self.eventStore!
        addController.editViewDelegate = self
        self.presentViewController(addController, animated: true, completion: nil)
    }
    
    
    //MARK: -
    //MARK: EKEventEditViewDelegate
    
    // Overriding EKEventEditViewDelegate method to update event store according to user actions.
    func eventEditViewController(controller: EKEventEditViewController, didCompleteWithAction action: EKEventEditViewAction) {
        // Dismiss the modal view controller
        self.dismissViewControllerAnimated(true) {[weak self] in
            if action != .Canceled {
                dispatch_async(dispatch_get_main_queue()) {
                    // Re-fetch all events happening in the next 24 hours
                    self?.eventsList = self!.fetchEvents()
                    // Update the UI with the above events
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    
    // Set the calendar edited by EKEventEditViewController to our chosen calendar - the default calendar.
    func eventEditViewControllerDefaultCalendarForNewEvents(controller: EKEventEditViewController) -> EKCalendar {
        return self.defaultCalendar
    }
    
}